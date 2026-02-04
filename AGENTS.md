# Repository Guidelines

## Project Structure & Module Organization
- Core runtime config lives at the repo root: `docker-compose.yml`, `docker-compose.n8n-workers.yml`, and `Caddyfile`.
- Installer and maintenance logic is in `scripts/` (install, update, doctor, cleanup, and helpers).
- Service-specific assets are grouped by folder (examples: `n8n/`, `grafana/`, `prometheus/`, `searxng/`, `ragflow/`, `python-runner/`, `welcome/`).
- Shared files for workflows are stored in `shared/` and mounted inside containers as `/data/shared`.

## Build, Test, and Development Commands
- `make install`: run the full installation wizard.
- `make update` or `make git-pull`: refresh images and configuration (fork-friendly via `make git-pull`).
- `make logs s=<service>`: tail a specific service’s logs (example: `make logs s=n8n`).
- `make doctor`: run system checks for DNS/SSL/containers.
- `make restart`, `make stop`, `make start`, `make status`: manage the compose stack.
- `make clean` or `make clean-all`: remove unused Docker resources (`clean-all` is destructive).

## Coding Style & Naming Conventions
- Bash scripts in `scripts/` use `#!/bin/bash`, 4-space indentation, and uppercase constants. Match existing formatting.
- Environment variable patterns are consistent: hostnames use `_HOSTNAME`, secrets use `_PASSWORD` or `_KEY`, and bcrypt hashes use `_PASSWORD_HASH`.
- Services should not publish ports directly; external access goes through Caddy.

## Testing Guidelines
- There is no unit-test suite. Use syntax checks instead:
- `docker compose -p localai config --quiet`
- `bash -n scripts/install.sh` (and other edited scripts)
- For installer changes, validate on a clean Ubuntu 24.04 LTS host and confirm profile selections start correctly.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits: `type(scope): summary` (examples in history include `fix(caddy): ...`, `docs(readme): ...`, `feat(postiz): ...`).
- PRs should include a short summary, affected services/profiles, and test commands run.
- Update `README.md` and `CHANGELOG.md` for user-facing changes or new services.
