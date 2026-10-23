#!/bin/bash
# =============================================================================
# apply_update.sh - Service update and restart logic
# =============================================================================
# Called by update.sh after git sync. Performs the actual service updates:
#   1. Updates .env with any new variables (03_generate_secrets.sh --update)
#   2. Runs service selection wizard (04_wizard.sh) to update profiles
#   3. Configures services (05_configure_services.sh)
#   4. Pulls latest Docker images for selected services and builds local ones (with retries)
#   5. Restarts all services (06_run_services.sh)
#   6. Displays final report (07_final_report.sh)
#
# Handles multiple compose files: main, n8n-workers, Supabase, and Dify.
#
# Usage: Called automatically by update.sh (not typically run directly)
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Source git utilities
source "$SCRIPT_DIR/git.sh"

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# Setup error telemetry trap for tracking failures
setup_error_telemetry_trap

# Set the compose command explicitly to use docker compose subcommand
COMPOSE_CMD="docker compose"

# Path to the 06_run_services.sh script
RUN_SERVICES_SCRIPT="$SCRIPT_DIR/06_run_services.sh"

# Check if run services script exists
require_file "$RUN_SERVICES_SCRIPT" "$RUN_SERVICES_SCRIPT not found."

cd "$PROJECT_ROOT"

# Repoint remotes still targeting the pre-rename repository URL. Also
# called here (not only in update.sh) so installations updating FROM an
# old version get healed in the same run: the old update.sh has already
# fetched the new code via GitHub's redirect by the time this executes.
git_heal_renamed_remotes

# Send telemetry: update started
send_telemetry "update_start"

# --- Call 03_generate_secrets.sh in update mode ---
set_telemetry_stage "update_env"
log_info "Ensuring .env file is up-to-date with all variables..."
bash "$SCRIPT_DIR/03_generate_secrets.sh" --update || {
    log_error "Failed to update .env configuration via 03_generate_secrets.sh. Update process cannot continue."
    exit 1
}
log_success ".env file updated successfully."
# --- End of .env update by 03_generate_secrets.sh ---

# --- Run Service Selection Wizard FIRST to get updated profiles ---
set_telemetry_stage "update_wizard"
log_info "Running Service Selection Wizard to update service choices..."
bash "$SCRIPT_DIR/04_wizard.sh" || {
    log_error "Service Selection Wizard failed. Update process cannot continue."
    exit 1
}
log_success "Service selection updated."
# --- End of Service Selection Wizard ---

# --- Configure Services (prompts and .env updates) ---
set_telemetry_stage "update_configure"
log_info "Configuring services (.env updates for optional inputs)..."
bash "$SCRIPT_DIR/05_configure_services.sh" || {
    log_error "Configure Services failed. Update process cannot continue."
    exit 1
}
log_success "Service configuration completed."

# Clean up legacy containers from old naming conventions
cleanup_legacy_n8n_workers
cleanup_legacy_postgresus
cleanup_legacy_comfyui

# Clean up services removed from the stack
cleanup_removed_hermes

# Pull latest versions of selected containers based on updated .env
set_telemetry_stage "update_docker_pull"
log_info "Pulling latest versions of selected containers..."

# Load environment to check active profiles (wizard may have updated them)
load_env

# Build compose files array using shared function (checks profile + file existence)
build_compose_files_array

# 06 stops the stack (`down`) before its own unretried `up -d` and `build --pull`, so anything that
# needs the registry happens here first, with retries, and a failure stops the update while the stack runs.
abort_before_restart() {
    # 03 rewrote .env as root; give it back so the non-sudo 'make pull' can read it
    bash "$SCRIPT_DIR/08_fix_permissions.sh" || log_warning "Fixing file permissions reported an error (see above); if .env is not readable, use 'sudo make pull'."
    log_error "Update stopped before restarting the stack. $1"
    exit 1
}

if ! pull_images_with_retry; then
    if [ ${#FAILED_PULLS[@]} -eq 0 ]; then
        abort_before_restart "Image pull aborted (see the error above)."
    fi
    MISSING_IMAGES=()
    for svc in "${FAILED_PULLS[@]}"; do
        # `config --images SERVICE` also lists the images of its depends_on services, so read its own key
        image=$($COMPOSE_CMD -p "localai" "${COMPOSE_FILES[@]}" config --format json "$svc" \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"][sys.argv[1]].get("image",""))' "$svc" 2>/dev/null) || image=""
        if [ -z "$image" ]; then
            log_error "Could not resolve the image of $svc; check the compose files with: docker compose -p localai config"
            MISSING_IMAGES+=("$svc")
        elif ! docker image inspect "$image" >/dev/null 2>&1; then
            MISSING_IMAGES+=("$svc")
        fi
    done
    if [ ${#MISSING_IMAGES[@]} -gt 0 ]; then
        abort_before_restart "No usable image for: ${MISSING_IMAGES[*]}. Run 'make pull', then 'make update' again; if the pull error says 'manifest unknown' or 'not found', check the image tag/version of that service in .env."
    fi
    log_warning "Could not pull new images for: ${FAILED_PULLS[*]}. They will be recreated from the image already on the server; continuing the update."
fi

# Locally built images (n8n, its runners, OpenClaw); Supabase/Dify files are left out, as in 06's main-stack build
set_telemetry_stage "update_docker_build"
log_info "Building local images..."
BUILD_COMPOSE_FILES=()
for ((i = 1; i < ${#COMPOSE_FILES[@]}; i += 2)); do
    case "${COMPOSE_FILES[i]}" in
        */supabase/docker/*|*/dify/docker/*) ;;
        *) BUILD_COMPOSE_FILES+=("-f" "${COMPOSE_FILES[i]}") ;;
    esac
done
if ! compose_with_retry "Build of local images" "${BUILD_COMPOSE_FILES[@]}" build --pull; then
    abort_before_restart "Could not build the local images. Check the network and run 'make update' again."
fi

# Start PostgreSQL first to initialize databases before other services
set_telemetry_stage "update_db_init"
log_info "Starting PostgreSQL..."
$COMPOSE_CMD -p "localai" up -d postgres || { log_error "Failed to start PostgreSQL"; exit 1; }

# Initialize PostgreSQL databases for services (creates if not exist)
# This must run BEFORE other services that depend on these databases
source "$SCRIPT_DIR/databases.sh"
init_all_databases || { log_warning "Database initialization had issues, but continuing..."; }

# Start all services using the 06_run_services.sh script (postgres is already running)
set_telemetry_stage "update_services_start"
log_info "Running Services..."
bash "$RUN_SERVICES_SCRIPT" || { log_error "Failed to start services. Check logs for details."; exit 1; }

if [ ${#FAILED_PULLS[@]} -eq 0 ]; then
    log_success "Update application completed successfully!"
else
    log_warning "Update applied, but some services may still run their previous image (listed at the end)."
fi

# --- Fix file permissions ---
set_telemetry_stage "update_fix_perms"
log_info "Fixing file permissions..."
bash "$SCRIPT_DIR/08_fix_permissions.sh" || {
    log_warning "Fixing file permissions reported an error (see above). The services were updated; follow the message above to fix what it names."
}
# --- End of Fix permissions ---

# --- Display Final Report with Credentials ---
set_telemetry_stage "update_final_report"
bash "$SCRIPT_DIR/07_final_report.sh" || {
    log_warning "Failed to display the final report. This does not affect the update."
    # We don't exit 1 here as the update itself was successful.
}
# --- End of Final Report ---

if [ ${#FAILED_PULLS[@]} -gt 0 ]; then
    log_warning "These services may still run their previous image, because the new one could not be downloaded: ${FAILED_PULLS[*]}"
    log_warning "They may not work with the updated services; check 'make status' and 'make doctor'. To finish the update, run: make pull && make restart"
fi

# Send telemetry: update completed with current services
send_telemetry "update_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
