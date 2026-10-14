#!/bin/bash
# =============================================================================
# pull_images.sh - Pull the latest images for the selected services
# =============================================================================
# Only the image pull of `make update`, with per-service retries; skips n8n, its runners and
# OpenClaw (built locally) and recreates no containers - run `make restart` afterwards.
#
# Usage: bash scripts/pull_images.sh
# =============================================================================

set -e

source "$(dirname "$0")/utils.sh"
init_paths

cd "$PROJECT_ROOT"

# `make update` runs as root and leaves .env root-only if it stops early
if [ -f "$ENV_FILE" ] && [ ! -r "$ENV_FILE" ]; then
    log_error "$ENV_FILE is not readable by $(id -un). Run: sudo make pull"
    exit 1
fi

load_env

build_compose_files_array

if ! pull_images_with_retry; then
    if [ ${#FAILED_PULLS[@]} -gt 0 ]; then
        log_error "Could not pull images for: ${FAILED_PULLS[*]}. Check the network and run 'make pull' again; if the error says 'manifest unknown' or 'not found', check the image tag/version of that service in .env."
    fi
    exit 1
fi

log_success "Images pulled. Run 'make restart' to recreate the containers with the new images."
