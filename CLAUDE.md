# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **n8n-install**, a Docker Compose-based installer that provides a comprehensive self-hosted environment for n8n workflow automation and numerous AI/automation services. The installer includes an interactive wizard, automated secret generation, and integrated HTTPS via Caddy.

### Core Architecture

- **Profile-based service management**: Services are activated via Docker Compose profiles (e.g., `n8n`, `flowise`, `monitoring`). Profiles are stored in the `.env` file's `COMPOSE_PROFILES` variable.
- **No exposed ports**: Services do NOT publish ports directly. All external HTTPS access is routed through Caddy reverse proxy on ports 80/443.
- **Shared secrets**: Core services (Postgres, Valkey (Redis-compatible, container named `redis` for backward compatibility), Caddy) are always included. Other services are optional and selected during installation.
- **Queue-based n8n**: n8n runs in `queue` mode with Redis, Postgres, and dynamically scaled workers (`N8N_WORKER_COUNT`).

### Key Files

- `Makefile`: Common commands (install, update, logs, etc.)
- `docker-compose.yml`: Service definitions with profiles
- `Caddyfile`: Reverse proxy configuration with automatic HTTPS
- `.env`: Generated secrets and configuration (from `.env.example`)
- `scripts/install.sh`: Main installation orchestrator (runs numbered scripts 01-08 in sequence)
- `scripts/utils.sh`: Shared utility functions (sourced by all scripts via `source "$(dirname "$0")/utils.sh" && init_paths`)
- `scripts/01_system_preparation.sh`: System updates, firewall, security hardening
- `scripts/02_install_docker.sh`: Docker and Docker Compose installation
- `scripts/git.sh`: Git utilities (sync with origin, branch detection, configuration)
- `scripts/03_generate_secrets.sh`: Secret generation and bcrypt hashing
- `scripts/04_wizard.sh`: Interactive service selection using whiptail
- `scripts/05_configure_services.sh`: Service-specific configuration logic
- `scripts/databases.sh`: Creates isolated PostgreSQL databases for services (library)
- `scripts/telemetry.sh`: Anonymous telemetry functions (Scarf integration)
- `scripts/06_run_services.sh`: Starts Docker Compose stack
- `scripts/07_final_report.sh`: Post-install credential summary
- `scripts/08_fix_permissions.sh`: Fixes file ownership for non-root access
- `scripts/generate_n8n_workers.sh`: Generates dynamic worker/runner compose file
- `scripts/update.sh`: Update orchestrator (syncs with origin and updates images)
- `scripts/update_preview.sh`: Preview available updates without applying (dry-run)
- `scripts/doctor.sh`: System diagnostics (DNS, SSL, containers, disk, memory)
- `scripts/apply_update.sh`: Applies updates after git sync
- `scripts/docker_cleanup.sh`: Removes unused Docker resources (used by `make clean`)
- `scripts/download_top_workflows.sh`: Downloads community n8n workflows
- `scripts/import_workflows.sh`: Imports workflows from `n8n/backup/workflows/` into n8n (used by `make import`)
- `scripts/restart.sh`: Restarts services with proper compose file handling (used by `make restart`)
- `scripts/setup_custom_tls.sh`: Configures custom TLS certificates (used by `make setup-tls`)

**Project Name**: All docker-compose commands use `-p localai` (defined in Makefile as `PROJECT_NAME := localai`).

**Version**: Stored in `VERSION` file at repository root.

### Installation Flow

`scripts/install.sh` orchestrates the installation by running numbered scripts in sequence:

1. `01_system_preparation.sh` - System updates, firewall, security hardening
2. `02_install_docker.sh` - Docker and Docker Compose installation
3. `03_generate_secrets.sh` - Generate passwords, API keys, bcrypt hashes
4. `04_wizard.sh` - Interactive service selection (whiptail UI)
5. `05_configure_services.sh` - Service-specific configuration
6. `06_run_services.sh` - Start Docker Compose stack
7. `07_final_report.sh` - Display credentials and URLs
8. `08_fix_permissions.sh` - Fix file ownership for non-root access

The update flow (`scripts/update.sh`) similarly orchestrates: git fetch + reset → service selection → `apply_update.sh` → restart.

**Git update modes**: Default is `reset` (hard reset to origin). Set `GIT_MODE=merge` in `.env` for fork workflows (merges from upstream instead of hard reset). The `make git-pull` command uses merge mode.

## Common Development Commands

### Makefile Commands

```bash
make install           # Full installation (runs scripts/install.sh)
make update            # Update system and services (resets to origin)
make update-preview    # Preview available updates (dry-run)
make git-pull          # Update for forks (merges from upstream/main)
make clean             # Remove unused Docker resources (preserves data)
make clean-all         # Remove ALL Docker resources including data (DANGEROUS)

make logs              # View logs (all services)
make logs s=<service>  # View logs for specific service
make status            # Show container status
make monitor           # Live CPU/memory monitoring (docker stats)
make restart           # Restart all services
make stop              # Stop all services
make start             # Start all services
make show-restarts     # Show restart count per container
make doctor            # Run system diagnostics (DNS, SSL, containers, disk, memory)
make import            # Import n8n workflows from backup
make import n=10       # Import first N workflows only
make setup-tls         # Configure custom TLS certificates

make switch-beta       # Switch to develop branch and update
make switch-stable     # Switch to main branch and update
make help              # Show all available commands
```


## Adding a New Service

Follow this workflow when adding a new optional service (refer to `.claude/commands/add-new-service.md` for complete details):

1. **docker-compose.yml**: Add service with `profiles: ["myservice"]`, `restart: unless-stopped`. Do NOT expose ports.
2. **Caddyfile**: Add reverse proxy block using `{$MYSERVICE_HOSTNAME}`. Consider if basic auth is needed.
3. **.env.example**: Add `MYSERVICE_HOSTNAME=myservice.yourdomain.com` and credentials if using basic auth.
4. **scripts/03_generate_secrets.sh**: Generate passwords and bcrypt hashes. Add to `VARS_TO_GENERATE` map.
5. **scripts/04_wizard.sh**: Add service to `base_services_data` array for wizard selection.
6. **scripts/databases.sh**: If service uses PostgreSQL, add database name to `INIT_DB_DATABASES` array.
7. **scripts/generate_welcome_page.sh**: Add service to `SERVICES_ARRAY` for welcome dashboard.
8. **welcome/app.js**: Add `SERVICE_METADATA` entry with name, description, icon, color, category.
9. **scripts/07_final_report.sh**: Add service URL and credentials output using `is_profile_active "myservice"`.
10. **README.md**: Add one-line description under "What's Included".
11. **CHANGELOG.md**: Add entry under `## [Unreleased]` → `### Added` (new service = minor version bump).

**Always ask users if the new service requires Caddy basic auth protection.**

## Versioning (CHANGELOG.md)

This project uses [Semantic Versioning](https://semver.org/). When updating `CHANGELOG.md`:

### Version Format: `MAJOR.MINOR.PATCH`

| Type | When to bump | Examples |
|------|--------------|----------|
| **MAJOR** (X.0.0) | Breaking changes that require user action | n8n 2.0 migration, config format changes, removed features |
| **MINOR** (0.X.0) | New services or features (backward compatible) | Adding NocoDB, new wizard options, new Makefile commands |
| **PATCH** (0.0.X) | Bug fixes (backward compatible) | Healthcheck fixes, proxy bypass fixes, typo corrections |

### Changelog Entry Format

```markdown
## [Unreleased]

## [2.6.0] - 2026-01-15

### Added
- **NewService** - Brief description of what it provides

### Changed
- Description of modified behavior

### Fixed
- Description of bug fix
```

### After Release

1. Move items from `[Unreleased]` to new version section
2. Add comparison link at bottom of file:
   ```markdown
   [2.6.0]: https://github.com/kossakovsky/n8n-install/compare/v2.5.3...v2.6.0
   ```
3. Update `[Unreleased]` link to compare from new version

## Important Service Details

### n8n Configuration (v2.0+)

- n8n runs in `EXECUTIONS_MODE=queue` with Redis as the queue backend
- **OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true**: All executions (including manual tests) run on workers
- **Worker-Runner Sidecar Pattern**: Each worker has its own dedicated task runner
  - Workers and runners are generated dynamically via `scripts/generate_n8n_workers.sh`
  - Configuration stored in `docker-compose.n8n-workers.yml` (auto-generated, gitignored)
  - Runner connects to its worker via `network_mode: "service:n8n-worker-N"` (localhost:5679)
  - Runner image `n8nio/runners` must match n8n version
- **Template profile pattern**: `docker-compose.yml` defines `n8n-worker-template` and `n8n-runner-template` with `profiles: ["n8n-template"]` (never activated directly). `generate_n8n_workers.sh` uses these as templates to generate `docker-compose.n8n-workers.yml` with the actual worker/runner services.
- **Scaling**: Change `N8N_WORKER_COUNT` in `.env` and run `bash scripts/generate_n8n_workers.sh`
- **Code node libraries**: Configured via `n8n/n8n-task-runners.json` and `n8n/Dockerfile.runner`:
  - JS packages installed via `pnpm add` in Dockerfile.runner
  - Allowlist configured in `n8n-task-runners.json` (`NODE_FUNCTION_ALLOW_EXTERNAL`, `NODE_FUNCTION_ALLOW_BUILTIN`)
  - Default packages: `cheerio`, `axios`, `moment`, `lodash`
- Workflows can access the host filesystem via `/data/shared` (mapped to `./shared`)
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` allows Code nodes to access environment variables

### Caddy Reverse Proxy

- Automatically obtains Let's Encrypt certificates when `LETSENCRYPT_EMAIL` is set
- Hostnames are passed via environment variables (e.g., `N8N_HOSTNAME`, `FLOWISE_HOSTNAME`)
- Basic auth uses bcrypt hashes generated by `scripts/03_generate_secrets.sh` via Caddy's hash command
- Never add `ports:` to services in docker-compose.yml; let Caddy handle all external access
- **Caddy Addons** (`caddy-addon/`): Extend Caddy config without modifying the main Caddyfile. Files matching `site-*.conf` are auto-imported. TLS is controlled via `tls-snippet.conf` (all service blocks use `import service_tls`). See `caddy-addon/README.md` for details.

### External Compose Files (Supabase/Dify)

Complex services like Supabase and Dify maintain their own upstream docker-compose files:
- `start_services.py` handles cloning repos, preparing `.env` files, and starting services
- Each external service needs: `is_*_enabled()`, `clone_*_repo()`, `prepare_*_env()`, `start_*()` functions in `start_services.py`
- Both Supabase and Dify use **sparse checkout** to clone only the relevant subdirectory from upstream repos
- `scripts/utils.sh` provides `get_*_compose()` getter functions and `build_compose_files_array()` includes them
- `stop_all_services()` in `start_services.py` checks compose file existence (not profile) to ensure cleanup when a profile is removed
- All external compose files use the same project name (`-p localai`) so containers appear together
- `start_services.py` runs `docker build --pull` before starting services that have custom Dockerfiles

### SearXNG Initialization

SearXNG requires special initialization not handled by docker-compose alone:
- `start_services.py` generates a random `SEARXNG_SECRET_KEY` and writes `searxng/settings.yml` from a template
- On first start, `check_and_fix_docker_compose_for_searxng()` temporarily adds `cap_drop: []` to allow SearXNG to initialize, then removes it afterward
- If `searxng/settings.yml` already exists, initialization is skipped

### Postiz and temporal-ui

Postiz includes `temporal-ui` as a companion service:
- `temporal-ui` is a workflow orchestration admin UI used internally by Postiz
- Both services share the `postiz` Docker Compose profile
- `temporal-ui` is accessible via `TEMPORAL_UI_HOSTNAME` but is for admin use only

### neo4j

neo4j is a full-featured graph database service:
- Has its own entry in `scripts/databases.sh` (`INIT_DB_DATABASES`) for PostgreSQL isolation
- Accessible via `NEO4J_HOSTNAME`
- Used by LightRAG and other graph-aware RAG services

### Secret Generation

The `scripts/03_generate_secrets.sh` script:
- Generates random passwords, JWT secrets, API keys, and encryption keys
- Creates bcrypt password hashes using Caddy's `hash-password` command
- Preserves existing user-provided values in `.env`
- Supports different secret types via `VARS_TO_GENERATE` map: `password:32`, `jwt`, `api_key`, `base64:64`, `hex:32`

### Utility Functions (scripts/utils.sh)

Source with: `source "$(dirname "$0")/utils.sh" && init_paths`

Key functions:
- `is_profile_active "myservice"` - Check if profile is enabled
- `read_env_var "VAR_NAME"` / `write_env_var "VAR_NAME" "value"` - .env manipulation
- `load_env` - Source .env file to make variables available
- `update_compose_profiles "profile1,profile2"` - Update COMPOSE_PROFILES in .env
- `gen_password 32` / `gen_hex 64` / `gen_base64 64` - Secret generation
- `generate_bcrypt_hash "password"` - Create Caddy-compatible bcrypt hash (uses Caddy binary)
- `json_escape "string"` - Escape string for JSON output
- `require_command "cmd"` / `require_file "path"` / `ensure_file_exists "path"` - Prerequisite checks
- `validate_positive_integer "val"` - Validate integer input
- `start_spinner "msg"` / `stop_spinner` - Progress spinner for long operations
- `show_step N total "label"` / `show_progress "msg"` / `complete_progress` - Step progress tracking
- `save_debian_frontend` / `restore_debian_frontend` - Preserve DEBIAN_FRONTEND across apt installs
- `cleanup_bak_files "dir"` - Remove leftover `.bak` files
- `cleanup_legacy_n8n_workers` - Remove old n8n worker containers from previous naming convention
- `cleanup_legacy_postgresus` - Remove legacy postgresus container (renamed to databasus)
- `wt_input`, `wt_password`, `wt_yesno`, `wt_msg` - Whiptail dialog wrappers
- `wt_checklist`, `wt_radiolist`, `wt_menu` - Whiptail selection dialogs
- `wt_parse_choices "$result" array_name` - Parse quoted checklist output safely
- `wt_get_size` - Compute dialog dimensions for whiptail
- `log_info`, `log_success`, `log_warning`, `log_error` - Logging functions
- `log_header`, `log_subheader`, `log_divider`, `log_box` - Formatted output
- `print_ok`, `print_error`, `print_warning`, `print_info` - Doctor output helpers
- `get_real_user` / `get_real_user_home` - Get actual user even under sudo
- `backup_preserved_dirs` / `restore_preserved_dirs` - Directory preservation for git updates
- `get_n8n_workers_compose` / `get_supabase_compose` / `get_dify_compose` - Get compose file path if profile active AND file exists
- `build_compose_files_array` - Build global `COMPOSE_FILES` array with all active compose files (main + external)

### Service Profiles

**Core (always running, no profile):** `postgres`, `redis` (Valkey), `caddy`, `welcome`

**Automation / AI Agents:**
- `n8n`: n8n workflow automation (main app, worker, runner, import services)
- `flowise`: Flowise AI agent builder
- `open-webui`: Open WebUI chat interface for Ollama
- `letta`: Letta (MemGPT) stateful AI agent framework
- `dify`: Dify LLM app platform (uses external compose via `start_services.py`)

**Hardware / Inference:**
- `cpu`: Ollama CPU-only inference
- `gpu-nvidia`: Ollama with NVIDIA GPU support (mutually exclusive with cpu/gpu-amd)
- `gpu-amd`: Ollama with AMD GPU support (mutually exclusive with cpu/gpu-nvidia)
- `comfyui`: ComfyUI image/video generation (GPU-accelerated)
- `libretranslate`: Local machine translation service

**Vector Databases & Knowledge Graphs:**
- `qdrant`: Qdrant vector database
- `weaviate`: Weaviate vector database
- `neo4j`: Neo4j graph database (has its own PostgreSQL database)
- `lightrag`: LightRAG knowledge graph retrieval

**RAG / Document Processing:**
- `ragapp`: RAGapp document Q&A
- `ragflow`: RAGFlow document pipeline
- `docling`: Docling document parsing/conversion
- `paddleocr`: PaddleOCR optical character recognition
- `gotenberg`: Gotenberg document conversion (internal, no external access)
- `crawl4ai`: Crawl4AI web scraping (internal, no external access)

**Databases / Storage:**
- `databasus`: Databasus database management UI
- `nocodb`: NocoDB no-code database UI

**Monitoring & Observability:**
- `monitoring`: Prometheus, Grafana, cAdvisor, node-exporter
- `langfuse`: Langfuse LLM observability (ClickHouse, MinIO, worker, web)

**Social / Communication:**
- `postiz`: Postiz social media scheduler (includes temporal-ui for admin)
- `waha`: WAHA WhatsApp HTTP API

**Search:**
- `searxng`: SearXNG private search engine (requires `settings.yml` generation; see SearXNG note below)

**Infrastructure:**
- `portainer`: Portainer Docker management UI
- `cloudflare-tunnel`: Cloudflare Tunnel for zero-trust access (see `cloudflare-instructions.md`)
- `gost`: HTTP/HTTPS proxy for routing AI service outbound traffic
- `python-runner`: Internal Python execution environment (no external access)
- `supabase`: Supabase backend-as-a-service (uses external compose via `start_services.py`)

## Architecture Patterns

### Healthchecks

Services should define healthchecks for proper dependency management:
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
```

### Service Dependencies

Use `depends_on` with conditions:
```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
```

### Environment Variable Patterns

- All secrets/passwords end with `_PASSWORD` or `_KEY`
- All hostnames end with `_HOSTNAME`
- Password hashes end with `_PASSWORD_HASH`
- Use `${VAR:-default}` for optional vars with defaults

### Profile Activation Logic

In bash scripts, check if a profile is active:
```bash
if is_profile_active "myservice"; then
  # Service-specific logic
fi
```

### Proxy Configuration (for AI services)

Services making outbound HTTP requests to AI APIs (OpenAI, Anthropic, etc.) should use the shared proxy anchor:
```yaml
x-proxy-env: &proxy-env
  HTTP_PROXY: ${GOST_PROXY_URL:-}
  HTTPS_PROXY: ${GOST_PROXY_URL:-}
  NO_PROXY: ${GOST_NO_PROXY:-}

services:
  myservice:
    environment:
      <<: *proxy-env  # Inherit proxy settings
```

**Important:** Healthchecks must bypass proxy:
```yaml
healthcheck:
  test: ["CMD-SHELL", "http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= wget -qO- http://localhost:8080/health || exit 1"]
```

**GOST_NO_PROXY**: ALL service container names must be listed in `GOST_NO_PROXY` in `.env.example`. This prevents internal Docker network traffic from routing through the proxy. This applies to every service, not just those using `<<: *proxy-env`.

### Welcome Page Dashboard

The welcome page (`welcome/`) provides a post-install dashboard showing all active services:
- `scripts/generate_welcome_page.sh`: Generates `welcome/services.json` with service URLs, credentials, and metadata
- `welcome/app.js`: Contains `SERVICE_METADATA` object defining display properties (name, description, icon, color, category)
- Categories: `ai`, `database`, `monitoring`, `tools`, `infra`, `automation`
- Always use `json_escape "$VAR"` when building JSON to handle special characters

### Preserved Directories

Directories in `PRESERVE_DIRS` (defined in `scripts/utils.sh`) survive git updates:
- `python-runner/` - User's custom Python code

These are backed up before `git reset --hard` and restored after.

## Common Issues and Solutions

### Service won't start after adding
1. Ensure profile is added to `COMPOSE_PROFILES` in `.env`
2. Check logs: `docker compose -p localai logs <service>`
3. Verify no port conflicts (no services should publish ports)
4. Ensure healthcheck is properly defined if service has dependencies

### Caddy certificate issues
- DNS must be configured before installation (wildcard A record: `*.yourdomain.com`)
- Check Caddy logs for certificate acquisition errors
- Verify `LETSENCRYPT_EMAIL` is set in `.env`

### Password hash generation fails
- Ensure Caddy container is running: `docker compose -p localai up -d caddy`
- Script uses: `docker exec caddy caddy hash-password --plaintext "$password"`

### Monitoring (node-exporter + cAdvisor) kills the system on WSL2

**Symptom**: After starting the `monitoring` profile, Load Average spikes above 900, SSH session drops, system becomes unresponsive.

**Root cause — two processes, same bug**:

1. **node-exporter** (Go): tries to `stat()` every mounted filesystem to collect disk metrics. In WSL2 this includes Windows drives (`/mnt/c`, `/mnt/d`, ...) via `9p`/`drvfs` protocol. These calls hang indefinitely. Because node-exporter collects on a fixed interval, each timed-out goroutine is not cancelled before the next scrape spawns new ones — resulting in hundreds of concurrent blocked goroutines.

2. **cAdvisor** (Go): same problem — it traverses `/rootfs` (mapped to host `/`) to collect `disk`, `diskIO`, and `resctrl` metrics, hitting the same `/mnt/*` Windows paths with the same goroutine explosion.

**Fix — WSL2-only override file** (`docker-compose.wsl.yml`):
The fix is intentionally **not** applied in the main `docker-compose.yml` because it disables disk metrics, which would break monitoring on native Linux servers.

To enable on WSL2, set in `.env`:
```
WSL2_MODE=true
```

`build_compose_files_array()` in `scripts/utils.sh` detects this flag and automatically appends `docker-compose.wsl.yml` to the compose file list. The override:
- `node-exporter`: extends `--collector.filesystem.mount-points-exclude` to add `/mnt` and `/usr/lib/wsl`; adds `--collector.filesystem.fs-types-exclude` covering `9p` and `drvfs` types.
- `cAdvisor`: adds `--disable_metrics=disk,diskIO,resctrl,tcp,udp,percpu,sched,process` and `--docker_only=true` to prevent rootfs traversal.

**DO NOT move these flags into `docker-compose.yml`** — they will break disk metrics on production Linux servers.

## File Locations

- Shared files accessible by n8n: `./shared` (mounted as `/data/shared` in n8n)
- n8n storage: Docker volume `localai_n8n_storage`
- Service-specific volumes: Defined in `volumes:` section at top of `docker-compose.yml`
- Installation logs: stdout during script execution
- Service logs: `docker compose -p localai logs <service>`

## Testing Changes

### Syntax Validation

```bash
# Docker Compose syntax
docker compose -p localai config --quiet

# Bash script syntax (validate all key scripts)
bash -n scripts/utils.sh
bash -n scripts/git.sh
bash -n scripts/databases.sh
bash -n scripts/telemetry.sh
bash -n scripts/03_generate_secrets.sh
bash -n scripts/04_wizard.sh
bash -n scripts/05_configure_services.sh
bash -n scripts/07_final_report.sh
bash -n scripts/generate_welcome_page.sh
bash -n scripts/generate_n8n_workers.sh
bash -n scripts/apply_update.sh
bash -n scripts/update.sh
bash -n scripts/install.sh
```

### Full Testing

When modifying installer scripts:
1. Test on a clean Ubuntu 24.04 LTS system (minimum 4GB RAM / 2 CPU)
2. Verify all profile combinations work
3. Check that `.env` is properly generated
4. Confirm final report displays correct URLs and credentials
5. Test update script preserves custom configurations
