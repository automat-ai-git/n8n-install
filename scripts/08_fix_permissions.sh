#!/bin/bash
# =============================================================================
# 08_fix_permissions.sh - Fix file ownership after installation
# =============================================================================
# This script fixes file ownership when the installer was run with sudo.
# It detects the real user who invoked the installation and sets proper
# ownership for all project files except the containers' own data directories.
#
# Usage: bash scripts/08_fix_permissions.sh
# =============================================================================

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Initialize paths
init_paths

log_info "Fixing file permissions..."

# Get the real user who ran the installer
REAL_USER=$(get_real_user)
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")

log_info "Detected user: $REAL_USER (group: $REAL_GROUP)"

# Skip if running as root without sudo (e.g., in Docker)
if [[ "$REAL_USER" == "root" ]]; then
    log_info "Running as root user, no permission changes needed."
    exit 0
fi

# Data the containers write as their own users: supabase/postgres cannot open files owned by
# the host user. The git-tracked files next to them still go to the user.
SUPABASE_DB_DATA="$PROJECT_ROOT/supabase/docker/volumes/db/data"
CONTAINER_OWNED_DIRS=("$SUPABASE_DB_DATA" "$PROJECT_ROOT/supabase/docker/volumes/storage")
# Dify: the default stack plus the optional vector stores of its compose file
for dir in db/data mysql/data redis/data app/storage plugin_daemon sandbox/dependencies \
           weaviate qdrant chroma pgvector/data pgvecto_rs/data milvus/etcd milvus/milvus \
           milvus/minio opensearch/data myscale/data myscale/log couchbase/data \
           matrixone/data oceanbase/data opengauss/data iris seekdb unstructured; do
    CONTAINER_OWNED_DIRS+=("$PROJECT_ROOT/dify/docker/volumes/$dir")
done

if [[ -d "$PROJECT_ROOT" ]]; then
    # Backstop for Supabase Postgres data an earlier run gave the host user: recreating supabase-db
    # fixes it, a running one keeps failing until then. A symlinked data directory is left alone.
    if [[ -d "$SUPABASE_DB_DATA" && ! -L "$SUPABASE_DB_DATA" ]] && \
       pg_uid=$(docker exec supabase-db id -u postgres 2>/dev/null) && \
       [[ "$pg_uid" =~ ^[0-9]+$ ]] && \
       [[ -n "$(find "$SUPABASE_DB_DATA" ! -user "$pg_uid" -print -quit)" ]]; then
        log_warning "Supabase Postgres data files are not owned by the container's postgres user (uid $pg_uid), restoring them..."
        if chown -R "$pg_uid" "$SUPABASE_DB_DATA" && chmod 700 "$SUPABASE_DB_DATA"; then
            log_success "Supabase Postgres data ownership restored. Auth, REST and Realtime reconnect on their own (Docker restarts them)."
        else
            log_error "Could not restore $SUPABASE_DB_DATA - Supabase auth, REST and Realtime keep failing until its files belong to uid $pg_uid (chown -R $pg_uid, chmod 700 on the directory)."
        fi
    fi

    log_info "Setting ownership of $PROJECT_ROOT to $REAL_USER:$REAL_GROUP"
    prune_args=()
    for dir in "${CONTAINER_OWNED_DIRS[@]}"; do
        prune_args+=(-path "$dir" -prune -o)
    done
    find "$PROJECT_ROOT" "${prune_args[@]}" -exec chown -h "$REAL_USER:$REAL_GROUP" {} +

    # Ensure .env has restricted permissions (readable only by owner)
    if [[ -f "$ENV_FILE" ]]; then
        chmod 600 "$ENV_FILE"
        log_info "Set restrictive permissions on .env file"
    fi

    # Ensure scripts are executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    chmod +x "$PROJECT_ROOT"/*.py 2>/dev/null || true

    log_success "File permissions fixed successfully!"
else
    log_error "Project root not found: $PROJECT_ROOT"
    exit 1
fi
