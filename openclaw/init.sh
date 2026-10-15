#!/bin/sh
# One-shot setup for the openclaw gateway. Runs as root on every
# 'docker compose up' (install, make update, make restart) - not when Docker
# itself restarts the gateway (crash, reboot, 'docker restart').
#
# 1. Copies the host SSH key and config (./openclaw/ssh) into the openclaw_ssh
#    volume owned by node. On the host the key stays with root / the installing
#    user, never uid 1000; the volume copy lives under /var/lib/docker, which
#    only root can enter.
# 2. Enforces the gateway keys below with 'config set' as node: trusted-proxy
#    auth (Caddy basic auth is the only login; Caddy passes the user in
#    X-Forwarded-User and new browsers are auto-approved), trusting only the
#    private openclaw-proxy network that only caddy, openclaw and this container
#    join; this container reads the subnet from its own interface. The subnet
#    also holds the bridge gateway (.1), i.e. the host: any process on the
#    host, of any user, can forge the header. Accepted because the stack assumes
#    a single-admin server whose users already have root/docker access; pin
#    Caddy's IP to /32 if that changes. Everything else in openclaw.json (models, channel policies,
#    agents...) stays under the user's control in the dashboard. The config
#    schema is strict: an unknown key stops the gateway, so check the upstream
#    schema before adding keys.
#
# A failed subnet lookup or 'config set' is reported but does not fail this
# container: that would abort 'docker compose up' for the whole stack. 'make
# doctor' and the final report show it (openclaw_init_failed in utils.sh).
# The one exception: if the gateway config cannot be changed at all, an old
# subnet may still be trusted, so this container fails and the gateway, which
# waits for it, does not start.
set -e

if [ -f /ssh-src/id_ed25519 ] && [ -f /ssh-src/config ]; then
    install -d -o node -g node -m 700 /home/node/.ssh
    install -o node -g node -m 600 /ssh-src/id_ed25519 /ssh-src/config /home/node/.ssh/
else
    echo "openclaw-init: WARNING: no SSH key in ./openclaw/ssh; a copy already in the volume is kept, otherwise 'ssh host' will not work until the installer or 'make update' creates it" >&2
fi

# Telegram is only switched on here; with an empty .env token the channel is
# left as configured in the dashboard (the token may live in openclaw.json).
telegram_entry=""
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    telegram_entry=', {"path": "channels.telegram.enabled", "value": true}'
fi

set_config() {
    runuser -u node -- node dist/index.js config set --batch-json "$1"
}

# ${OPENCLAW_HOSTNAME} / ${OPENCLAW_USERNAME} stay literal (single quotes) and are
# substituted by OpenClaw at load time, so changing them in .env only needs
# 'make restart'.
common_entries='
  {"path": "gateway.mode", "value": "local"},
  {"path": "gateway.bind", "value": "lan"},
  {"path": "gateway.controlUi.allowedOrigins", "value": ["https://${OPENCLAW_HOSTNAME}"]}'"$telegram_entry"

# Subnet of openclaw-proxy: the only non-loopback IPv4 interface here
proxy_cidr="$(node -e '
const ifs = Object.values(require("os").networkInterfaces()).flat()
    .filter((i) => i.family === "IPv4" && !i.internal);
if (ifs.length !== 1) {
    console.error("openclaw-init: expected one IPv4 interface, found: " +
        (ifs.map((i) => i.address).join(", ") || "none"));
    process.exit(1);
}
const a = ifs[0].address.split(".").map(Number);
const m = ifs[0].netmask.split(".").map(Number);
const bits = m.reduce((n, o) => n + o.toString(2).split("1").length - 1, 0);
console.log(a.map((o, k) => o & m[k]).join(".") + "/" + bits);
')" || proxy_cidr=""
# Password login with no trusted proxy at all: a subnet written by an earlier run
# may now belong to another Docker network, so it must never stay trusted.
fall_back_to_password() {
    echo "openclaw-init: ERROR: $1" >&2
    if set_config '[
  {"path": "gateway.auth.mode", "value": "password"},
  {"path": "gateway.trustedProxies", "value": []},'"$common_entries"'
]'; then
        echo "openclaw-init: ERROR: switched to password login. The dashboard asks for OPENCLAW_GATEWAY_PASSWORD from .env; approve the browser with make openclaw a=\"devices list\", then a=\"devices approve <requestId>\"." >&2
    elif set_config '[{"path": "gateway.trustedProxies", "value": []}]'; then
        # Last resort: drop the trust even if the rest of the batch is rejected
        echo "openclaw-init: ERROR: password login could not be configured either (see above); trusted proxies cleared, so the dashboard rejects every login (a fresh install may not start) until the config error is fixed and 'make restart' is run." >&2
    else
        echo "openclaw-init: ERROR: could not change the gateway config at all (see above); it may still trust an old subnet, so the gateway is not started until this is fixed." >&2
        exit 1
    fi
    exit 0
}

# An openclaw-init container created before 1.14.1 sits on the default network
# ('make start' after 'git pull' reuses it with the new script), so its subnet
# must never become trusted. Only the current compose definition sets this.
if [ "$OPENCLAW_INIT_PROXY_NETWORK" != "true" ]; then
    fall_back_to_password "this openclaw-init container predates the openclaw-proxy network; run 'make restart'"
fi

if [ -z "$proxy_cidr" ]; then
    fall_back_to_password "could not determine the openclaw-proxy subnet"
fi

# operator.admin lets the owner configure models and channels from the dashboard
set_config '[
  {"path": "gateway.auth.mode", "value": "trusted-proxy"},
  {"path": "gateway.auth.trustedProxy", "value": {
    "userHeader": "x-forwarded-user",
    "allowUsers": ["${OPENCLAW_USERNAME}"],
    "deviceAutoApprove": {"enabled": true, "scopes": ["operator.admin", "operator.read", "operator.write", "operator.approvals", "operator.questions"]}
  }},
  {"path": "gateway.trustedProxies", "value": ["'"$proxy_cidr"'"]},'"$common_entries"'
]' || fall_back_to_password "'config set' for trusted-proxy login failed (see above)"
