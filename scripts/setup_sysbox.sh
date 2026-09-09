#!/bin/bash
# =============================================================================
# setup_sysbox.sh - Installs Sysbox (sysbox-runc) for the n8n Assistant sandbox
# =============================================================================
# The sandbox runner (sandbox-runner-1) is a Docker-in-Docker container. Sysbox
# lets it run WITHOUT --privileged. This script installs the upstream sysbox-ce
# package non-interactively, registers the sysbox-runc runtime with Docker and
# proves it works by starting a test container under it.
#
# Called by 05_configure_services.sh on every install/update while the
# n8n-sandbox profile is active. Exit 0 when sysbox-runc is registered and the
# test container ran (an already installed Sysbox is re-tested, not trusted).
# Any failure exits 1 with a logged "Sysbox: <reason>" line, so the caller can
# offer the privileged fallback. A failed apt-get install purges sysbox-ce
# again so later apt runs keep working; a failed post-install check leaves the
# package installed and reports why.
#
# Why /etc/docker/daemon.json is touched: the sysbox-ce package checks the file
# for a "bip" and a "default-address-pools" entry (a regex on pretty-printed
# JSON, see sysbox-pkgr deb/sysbox-ce/sysbox-ce.config). When they are missing
# it writes its own values (bip 172.20.0.1/16 and a /24 pool) and restarts
# Docker - and refuses to install at all while any container exists, which is
# the case during 'make update'. Pre-seeding both keys with the values Docker is
# already using changes nothing about networking, needs no Docker restart, and
# makes the package only register the runtime and reload dockerd (SIGHUP).
# Hosts with a custom Docker network setup are rejected instead of guessed at.
#
# Usage: sudo bash scripts/setup_sysbox.sh
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/utils.sh"
init_paths

export DEBIAN_FRONTEND=noninteractive

SYSBOX_VERSION="0.7.1"
SYSBOX_BASE_URL="https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}"
SYSBOX_SHA256_AMD64="9d6d5484f980d0a17f86c492c1262015c2afb66280bdb97215b79fde6a0261c5"
SYSBOX_SHA256_ARM64="04ca894ae0b53f0fa54eaacc173ce40363c9a95ea5450f773716a84ef650a69b"
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
SMOKE_IMAGE="alpine:3"
SYSBOX_DEB_PATH=""
DAEMON_JSON_TMP=""

cleanup() {
    [ -n "${SYSBOX_DEB_PATH:-}" ] && rm -f "$SYSBOX_DEB_PATH"
    [ -n "${DAEMON_JSON_TMP:-}" ] && rm -f "$DAEMON_JSON_TMP"
    return 0
}
trap cleanup EXIT
# Anything not covered by an explicit fail() below still gets a "Sysbox:" line,
# which 05_configure_services.sh shows in its fallback dialog.
trap 'log_error "Sysbox: unexpected failure at line $LINENO: $BASH_COMMAND"' ERR

fail() {
    log_error "Sysbox: $1"
    exit 1
}

sysbox_runtime_registered() {
    docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"sysbox-runc"'
}

sysbox_installed() {
    [ "$(dpkg-query -W -f='${Status}' sysbox-ce 2>/dev/null)" = "install ok installed" ] \
        && command -v sysbox-runc >/dev/null 2>&1
}

[ "$EUID" -eq 0 ] || fail "must run as root (sudo)."
command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
docker info >/dev/null 2>&1 || fail "the Docker daemon is not running."

if sysbox_installed; then
    log_info "Sysbox is already installed; checking that it works..."
else
    log_info "Installing Sysbox ${SYSBOX_VERSION} so the n8n sandbox runner can run without --privileged..."

    # ------------------------------------------------------------------------
    # Preflight: everything Sysbox and n8n's sandbox need, checked before
    # anything on the host is changed. Kernel > 5.19 is n8n-sandbox-service's
    # requirement.
    # ------------------------------------------------------------------------
    case "$(uname -m)" in
        x86_64)  SYSBOX_ARCH="amd64"; SYSBOX_SHA256="$SYSBOX_SHA256_AMD64" ;;
        aarch64) SYSBOX_ARCH="arm64"; SYSBOX_SHA256="$SYSBOX_SHA256_ARM64" ;;
        *) fail "unsupported CPU architecture $(uname -m) (amd64 and arm64 only)." ;;
    esac

    [ -f /etc/os-release ] || fail "cannot detect the distribution (/etc/os-release missing)."
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_MAJOR="${VERSION_ID:-}"
    OS_MAJOR="${OS_MAJOR%%.*}"
    case "${OS_ID}:${OS_MAJOR}" in
        ubuntu:20|ubuntu:22|ubuntu:24|debian:11) ;;
        *) fail "unsupported distribution ${OS_ID:-?} ${VERSION_ID:-?} (Ubuntu 20.04/22.04/24.04 or Debian 11)." ;;
    esac

    KERNEL_RELEASE="$(uname -r)"
    IFS='.-' read -r KERNEL_MAJOR KERNEL_MINOR _ <<< "$KERNEL_RELEASE"
    if [ "$KERNEL_MAJOR" -lt 5 ] || { [ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -le 19 ]; }; then
        fail "kernel ${KERNEL_RELEASE} is too old (n8n's sandbox needs > 5.19; on Ubuntu 22.04 install linux-generic-hwe-22.04)."
    fi

    case "$(command -v docker)" in
        /snap/*) fail "Docker is installed from snap, which Sysbox does not support." ;;
    esac
    command -v systemctl >/dev/null 2>&1 && pidof systemd >/dev/null 2>&1 || fail "systemd is required."
    if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container --quiet; then
        fail "this host is itself a container ($(systemd-detect-virt --container)); Sysbox needs a VM or bare metal."
    fi
    [ -e /dev/fuse ] || fail "/dev/fuse is missing."
    command -v findmnt >/dev/null 2>&1 || fail "findmnt is missing (util-linux)."
    # Sysbox keeps its data store under /var/lib/sysbox and requires ext4 or
    # btrfs there and under Docker's data root, which is often a separate disk.
    DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
    for fs_path in /var/lib "${DOCKER_ROOT:-/var/lib/docker}"; do
        FSTYPE="$(findmnt -no FSTYPE -T "$fs_path" 2>/dev/null || true)"
        case "$FSTYPE" in
            ext4|btrfs) ;;
            *) fail "${fs_path} is on '${FSTYPE:-unknown}'; Sysbox needs ext4 or btrfs there." ;;
        esac
    done

    # ------------------------------------------------------------------------
    # Dependencies. jq is a Pre-Depends of sysbox-ce and is used below;
    # everything else (fuse, rsync, iptables, lsb-release) is resolved by apt
    # from the .deb. Installing 'fuse' explicitly would conflict with fuse3 on
    # Ubuntu 22.04/24.04.
    # ------------------------------------------------------------------------
    log_info "Installing prerequisites..."
    apt-get update -qq || fail "apt-get update failed."
    apt-get install -y -qq jq curl >/dev/null || fail "could not install jq and curl."
    apt-get install -y -qq "linux-headers-$(uname -r)" >/dev/null 2>&1 \
        || log_warning "linux-headers-$(uname -r) is not available; Sysbox works without it."

    # ------------------------------------------------------------------------
    # Docker network configuration must be one we can mirror into daemon.json
    # without changing anything. Anything custom is left alone: fall back.
    # ------------------------------------------------------------------------
    DOCKERD_ARGS="$(ps -o args= -C dockerd 2>/dev/null || true)"
    if grep -qE -- '(^|[[:space:]])(-b|--bridge|--bip|--default-address-pool|--fixed-cidr)([= ]|$)' <<< "$DOCKERD_ARGS"; then
        fail "dockerd runs with -b/--bridge/--bip/--default-address-pool/--fixed-cidr flags; install Sysbox manually (see README)."
    fi
    if [ -s "$DOCKER_DAEMON_JSON" ]; then
        jq -e 'type == "object"' "$DOCKER_DAEMON_JSON" >/dev/null 2>&1 \
            || fail "$DOCKER_DAEMON_JSON is not a valid JSON object; fix it first."
        if jq -e 'has("bridge") or has("fixed-cidr") or has("fixed-cidr-v6") or .ipv6 == true' "$DOCKER_DAEMON_JSON" >/dev/null; then
            fail "$DOCKER_DAEMON_JSON has a custom bridge/fixed-cidr/ipv6 setup; install Sysbox manually (see README)."
        fi
    fi
    # dockerd is running (checked above), so with the default network setup
    # docker0 exists and has an address. Anything else is a custom setup.
    DOCKER0_CIDR="$(ip -4 -o addr show docker0 2>/dev/null | awk '{print $4}' | head -n1 || true)"
    [ -n "$DOCKER0_CIDR" ] || fail "the docker0 bridge is missing or has no IPv4 address (custom -b/--bridge setup?); install Sysbox manually (see README)."

    # ------------------------------------------------------------------------
    # Download and verify the package before anything on the host is modified
    # ------------------------------------------------------------------------
    SYSBOX_DEB="sysbox-ce_${SYSBOX_VERSION}-0.linux_${SYSBOX_ARCH}.deb"
    SYSBOX_DEB_PATH="/var/cache/apt/archives/${SYSBOX_DEB}"   # readable by the _apt user
    log_info "Downloading ${SYSBOX_DEB}..."
    curl -fsSL -o "$SYSBOX_DEB_PATH" "${SYSBOX_BASE_URL}/${SYSBOX_DEB}" || fail "download of ${SYSBOX_DEB} failed."
    echo "${SYSBOX_SHA256}  ${SYSBOX_DEB_PATH}" | sha256sum -c - >/dev/null || fail "checksum mismatch for ${SYSBOX_DEB}."
    chmod 0644 "$SYSBOX_DEB_PATH"

    # ------------------------------------------------------------------------
    # Pre-seed daemon.json (see header). Only missing or empty keys are added;
    # the rest of the file is kept. bip is docker0's live address. The pool
    # list is Docker's built-in default: dockerd cannot report the active one,
    # but custom pool flags were rejected above and an existing key is kept, so
    # the default is also the active one. The package's check needs the
    # pretty-printed form.
    # ------------------------------------------------------------------------
    install -d -m 0755 /etc/docker
    [ -s "$DOCKER_DAEMON_JSON" ] || echo '{}' > "$DOCKER_DAEMON_JSON"
    DAEMON_JSON_TMP="$(mktemp /etc/docker/daemon.json.XXXXXX)"
    jq --indent 4 --arg bip "$DOCKER0_CIDR" '
        (if (.bip // "") == "" then .bip = $bip else . end)
        | (if ((."default-address-pools" // []) | length) == 0
           then ."default-address-pools" = [
               {"base": "172.17.0.0/12", "size": 16},
               {"base": "192.168.0.0/16", "size": 20}
           ] else . end)' "$DOCKER_DAEMON_JSON" > "$DAEMON_JSON_TMP" \
        || fail "could not rewrite $DOCKER_DAEMON_JSON with jq."
    chmod 0644 "$DAEMON_JSON_TMP"
    mv "$DAEMON_JSON_TMP" "$DOCKER_DAEMON_JSON"
    DAEMON_JSON_TMP=""
    log_info "Docker daemon.json now carries bip=${DOCKER0_CIDR} and the default address pools (the values Docker was already using)."

    # ------------------------------------------------------------------------
    # Install. A failed postinst would leave sysbox-ce half-configured and
    # break every later apt run (including 'make update'), so purge it again.
    # ------------------------------------------------------------------------
    log_info "Installing ${SYSBOX_DEB} (registers the sysbox-runc runtime, no Docker restart)..."
    if ! apt-get install -y -qq \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
        "$SYSBOX_DEB_PATH"; then
        log_warning "Sysbox: apt-get install failed; removing the half-installed sysbox-ce package..."
        PURGE_HINT=""
        if ! PURGE_OUTPUT="$(apt-get purge -y -qq sysbox-ce 2>&1 || dpkg --purge --force-all sysbox-ce 2>&1)"; then
            PURGE_HINT=" Removing the half-installed package also failed (${PURGE_OUTPUT##*$'\n'}); run 'sudo dpkg --purge --force-all sysbox-ce' and fix the error it prints before the next apt operation."
        fi
        fail "apt-get install of ${SYSBOX_DEB} failed (details are in the terminal after this dialog).${PURGE_HINT}"
    fi
fi

# ----------------------------------------------------------------------------
# Verify. Runs for a fresh install and for an already installed Sysbox alike:
# a Sysbox that stopped working must not be written into .env as the runtime.
# ----------------------------------------------------------------------------
command -v sysbox-runc >/dev/null 2>&1 || fail "sysbox-runc binary not found."
systemctl is-active --quiet sysbox || fail "the sysbox service is not running (systemctl status sysbox)."
if ! sysbox_runtime_registered; then
    # dockerd re-reads daemon.json on SIGHUP; the package sends one, but give it a moment.
    sleep 2
    sysbox_runtime_registered || fail "Docker did not register the sysbox-runc runtime (docker info | grep -i runtime)."
fi
# The test image is pulled separately so a Docker Hub rate limit or network
# failure is not mistaken for a broken Sysbox.
if ! docker image inspect "$SMOKE_IMAGE" >/dev/null 2>&1; then
    if ! PULL_OUTPUT="$(docker pull -q "$SMOKE_IMAGE" 2>&1)"; then
        fail "could not pull the test image ${SMOKE_IMAGE} (Docker Hub rate limit or no network?): ${PULL_OUTPUT##*$'\n'}"
    fi
fi
log_info "Running a Sysbox test container..."
if ! SMOKE_OUTPUT="$(docker run --rm --runtime=sysbox-runc "$SMOKE_IMAGE" true 2>&1)"; then
    fail "a test container failed to start under sysbox-runc: ${SMOKE_OUTPUT##*$'\n'}"
fi

log_success "Sysbox is installed and working; the n8n sandbox runner will use sysbox-runc."
