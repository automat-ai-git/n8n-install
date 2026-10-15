# Selfhost AI — One-Command Self-Hosted AI Stack (n8n, Ollama, Open WebUI, OpenClaw)

[![GitHub stars](https://img.shields.io/github/stars/kossakovsky/selfhost-ai?style=social)](https://github.com/kossakovsky/selfhost-ai/stargazers)
[![Latest release](https://img.shields.io/github/v/release/kossakovsky/selfhost-ai)](https://github.com/kossakovsky/selfhost-ai/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)

**Deploy 30+ open-source AI and automation tools on your own server with a single command.** Selfhost AI is a Docker Compose installer for a private AI homelab: n8n workflow automation, local LLMs with Ollama, a ChatGPT-style chat in Open WebUI, AI agents (OpenClaw, Flowise, Keelflow, Dify, Letta), RAG engines and vector databases (Qdrant, Weaviate, LightRAG, RAGFlow), Supabase, ComfyUI and Grafana monitoring. An interactive wizard picks the services, generates every secret and puts them all behind Caddy with automatic HTTPS. A free, self-hosted alternative to Zapier, Make and ChatGPT.

## Quick Start

You need a VPS with a public IP running **Ubuntu 24.04 LTS** (4 GB RAM / 2 CPU for n8n and monitoring; 20 GB RAM / 4 CPU / 60 GB disk for everything), a domain, and a **wildcard DNS record** `A *.yourdomain.com -> YOUR_SERVER_IP`. Then run:

```bash
git clone https://github.com/automat-ai-git/n8n-install && cd n8n-install && sudo bash ./scripts/install.sh
```

The wizard does the rest; see [Installation](#installation) for what it asks.

## Key Features

- **One-command install**: an interactive wizard, generated secrets and no manual configuration
- **Private AI homelab**: run LLMs locally with Ollama, on CPU, NVIDIA or AMD GPUs, including multi-GPU; your data stays on your server
- **ChatGPT alternative**: Open WebUI for local and API models, with an optional code-execution sandbox
- **Workflow automation**: n8n with 400+ integrations, queue mode with scalable workers, an MCP server for AI IDEs, and 300+ optional community workflows
- **AI agents and RAG**: OpenClaw (with Telegram), Flowise, Keelflow, Dify, Letta, LightRAG, RAGFlow, Qdrant, Weaviate
- **Automatic HTTPS**: Caddy reverse proxy with Let's Encrypt; services are reached only through Caddy (see [security notes](docs/security.md) for Supabase's ports); optional Cloudflare Tunnel
- **Built-in monitoring**: Grafana and Prometheus with an n8n workflow dashboard and ready-made alerts
- **Production ready**: health checks, service dependencies, `make doctor` diagnostics, and updates that preserve your settings
- **Free and open source**: Apache 2.0, no vendor lock-in

## What's Included

**Always installed:** [Caddy](https://caddyserver.com/) (reverse proxy and HTTPS), [PostgreSQL](https://www.postgresql.org/), and [Valkey](https://valkey.io/) (Redis-compatible). Everything below is optional and chosen in the wizard. "internal" means the service has no public URL and is reachable only from other containers.

### AI Chat and Agents

| Service | What it does | URL |
|---|---|---|
| [Open WebUI](https://openwebui.com/) | ChatGPT-like interface for local and API LLMs and n8n agents | `webui.` |
| [OpenClaw](https://docs.openclaw.ai) | Personal AI agent with a web dashboard, a Telegram bot, and full server access ([guide](docs/openclaw.md)) | `openclaw.` |
| [Open Terminal](https://docs.openwebui.com/features/open-terminal/) | Linux shell sandbox for Open WebUI agents, with a separate account per user ([guide](docs/open-terminal.md)) | internal |
| [Flowise](https://flowiseai.com/) | No-code / low-code AI agent builder (archived upstream) | `flowise.` |
| [Keelflow](https://github.com/Perruer/keelflow) | No-code / low-code AI agent builder, continuation of Flowise; can take over existing Flowise data ([guide](docs/keelflow.md)) | `keelflow.` |
| [Dify](https://dify.ai/) | AI application platform with LLMOps, RAG pipelines and agent orchestration | `dify.` |
| [Letta](https://docs.letta.com/) | Agent server and SDK with persistent memory (formerly MemGPT) | `letta.` |

### Workflow Automation

| Service | What it does | URL |
|---|---|---|
| [n8n](https://n8n.io/) | Workflow automation with 400+ integrations and AI nodes, in queue mode with workers ([guide](docs/n8n.md)) | `n8n.` |
| [n8n-MCP](https://github.com/czlonkowski/n8n-mcp) | MCP server that gives Claude Code, Cursor, Windsurf and VS Code n8n node docs and workflow tools | `n8n-mcp.` |
| [n8n Assistant sandbox](https://docs.n8n.io/deploy/host-n8n/configure-n8n/set-up-n8n-assistant) | Code-execution sandbox for n8n's AI Assistant and Agents, isolated with Sysbox, or privileged if you accept that ([guide](docs/n8n-assistant-sandbox.md)) | internal |
| [Postiz](https://postiz.com/) | Social media scheduling and publishing | `postiz.` |
| [WAHA](https://waha.devlike.pro/) | WhatsApp HTTP API (WEBJS, NOWEB and GOWS engines) | `waha.` |
| Python Runner | Runs your own Python code from `python-runner/` (`main.py`, `requirements.txt`, installed on every start) on the internal network | internal |

### Local LLMs and Image Generation

| Service | What it does | URL |
|---|---|---|
| [Ollama](https://ollama.com/) | Run Llama, Qwen, Mistral, Gemma and other LLMs locally, on CPU, NVIDIA or AMD, with multi-GPU support ([guide](docs/ollama-multi-gpu.md)) | `ollama.` (Bearer token) |
| [ComfyUI](https://github.com/comfyanonymous/ComfyUI) | Node-based Stable Diffusion / Flux image generation UI (NVIDIA, AMD or CPU; pin GPUs with `COMFYUI_GPU_DEVICES`) | `comfyui.` |
| [InvokeAI](https://invoke.ai/) | Stable Diffusion studio with a canvas, inpainting and a workflow editor; download a model in the Model Manager first | `invokeai.` |

### RAG, Vector and Graph Databases

| Service | What it does | URL |
|---|---|---|
| [Qdrant](https://qdrant.tech/) | High-performance vector database | `qdrant.` |
| [Weaviate](https://weaviate.io/) | AI-native vector database with hybrid search | `weaviate.` |
| [Supabase](https://supabase.com/) | Postgres backend with auth, storage and pgvector (a Firebase alternative) | `supabase.` |
| [Neo4j](https://neo4j.com/) | Graph database | `neo4j.` |
| [LightRAG](https://github.com/HKUDS/LightRAG) | Graph-based RAG with automatic knowledge-graph extraction | `lightrag.` |
| [RAGFlow](https://ragflow.io/) | RAG engine with deep document understanding and citations | `ragflow.` |
| [RAGApp](https://github.com/ragapp/ragapp) | RAG assistant over your data, with a web UI and an HTTP API | `ragapp.` |

### Documents, OCR, Web Scraping and Search

| Service | What it does | URL |
|---|---|---|
| [Docling](https://github.com/docling-project/docling-serve) | Converts PDF, DOCX, PPTX, XLSX, HTML and images to Markdown/JSON, with OCR; web UI at `/ui` | `docling.` |
| [PaddleOCR](https://www.paddleocr.ai/latest/en/index.html) | OCR API that runs on CPU | `paddleocr.` |
| [Gotenberg](https://gotenberg.dev/) | Converts HTML, Markdown and Office documents to PDF or images | internal |
| [Crawl4AI](https://github.com/unclecode/crawl4ai) | LLM-friendly web crawler and scraper | internal |
| [SearXNG](https://searxng.org/) | Private metasearch engine, also used as the web search for n8n's AI Assistant | `searxng.` |
| [LibreTranslate](https://docs.libretranslate.com/) | Self-hosted translation API (50+ languages) | `translate.` |

### Low-Code Apps and Data

| Service | What it does | URL |
|---|---|---|
| [Appsmith](https://www.appsmith.com/) | Low-code builder for internal tools and admin panels | `appsmith.` |
| [NocoDB](https://nocodb.com/) | Open-source Airtable alternative | `nocodb.` |

### Monitoring and Operations

| Service | What it does | URL |
|---|---|---|
| [Grafana](https://grafana.com/) + [Prometheus](https://prometheus.io/) | System and n8n workflow dashboards and alerts (with cAdvisor and node-exporter) | `grafana.`, `prometheus.` |
| [Langfuse](https://langfuse.com/) | LLM observability, tracing and evals | `langfuse.` |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Uptime monitoring with notifications | `uptime-kuma.` |
| [Portainer](https://www.portainer.io/) | Docker management UI (behind basic auth; create the Portainer admin on first login) | `portainer.` |
| [Databasus](https://github.com/databasus/databasus) | Database backups and monitoring | `databasus.` |
| [Gost](https://github.com/go-gost/gost) | Outbound HTTP/HTTPS proxy for AI services | internal |
| [Cloudflare Tunnel](cloudflare-instructions.md) | Zero-trust access without open ports | — |

URLs are subdomains of your domain, for example `n8n.yourdomain.com`.

## Installation

**Prerequisites**

1. **A domain name** with a wildcard A record, `*.yourdomain.com`, pointing to your server's IP, configured *before* installing.
2. **A VPS with a public IP address.** Home servers, shared hosting and localhost setups are not supported.
   - Operating system: Ubuntu 24.04 LTS, 64-bit
   - n8n, Monitoring, Databasus and Portainer: 4 GB RAM / 2 CPU cores / 40 GB disk
   - All services: at least 20 GB RAM / 4 CPU cores / 60 GB disk

**Run the installer** over SSH:

```bash
git clone https://github.com/automat-ai-git/n8n-install && cd n8n-install && sudo bash ./scripts/install.sh
```

The installer updates the system, configures the firewall and brute-force protection, installs Docker, generates `.env` with all secrets, and starts the services. It asks for:

1. Your **domain** (e.g. `yourdomain.com`).
2. Your **email**, used for service logins and for the Let's Encrypt certificate.
3. **Which services to install**, in a checklist wizard, plus follow-ups for some of them (hardware profile, Telegram bot token, Cloudflare token, ...).
4. An optional **OpenAI API key** (used by Supabase AI and Crawl4AI).
5. If n8n is selected: whether to **import ~300 community n8n workflows** (takes 20-30 minutes) and the **number of n8n workers** (each gets its own task runner).

At the end it prints the Welcome Page URL and login (**save them**). The Welcome dashboard at `welcome.yourdomain.com` lists every service's URL and credentials.

## Upgrading

```bash
make update     # pull the latest installer, update images, restart
make git-pull   # for forks: merge from upstream instead of resetting
```

`make update` resets tracked files such as `Caddyfile` and `docker-compose.yml`, so put your customizations in the places that survive updates:

- **Custom Caddy sites**: `caddy-addon/site-*.conf` (see [caddy-addon/README.md](caddy-addon/README.md))
- **Compose overrides**: a `docker-compose.override.yml` in the project root; it takes the highest precedence
- **Settings**: values in `.env` are kept (except `GOST_NO_PROXY`, which is regenerated to cover new services)

## Commands

| Command | Description |
|---|---|
| `make install` | Full installation |
| `make update` | Update the installer and all services |
| `make update-preview` | Preview available updates (dry run) |
| `make pull` | Pull the latest prebuilt images only (n8n and OpenClaw are rebuilt by `make update`); run `make restart` afterwards |
| `make git-pull` | Update a fork by merging from upstream |
| `make status` | Container status |
| `make logs` / `make logs s=n8n` | Logs for all services or for one |
| `make monitor` | Live CPU and memory usage |
| `make restart` / `make stop` / `make start` | Control the whole stack |
| `make show-restarts` | Restart count per container |
| `make doctor` | Diagnostics: DNS, SSL, containers, disk, memory |
| `make import` / `make import n=10` | Import n8n workflows from the backup |
| `make openclaw a="..."` | Run an OpenClaw CLI command |
| `make setup-tls` | Use custom TLS certificates instead of Let's Encrypt |
| `make clean` | Remove unused Docker images and containers (keeps data) |

Run `make help` for the full list.

## Guides

- [n8n: MCP server, Code node libraries, ffmpeg, file access and workflow monitoring](docs/n8n.md)
- [n8n Assistant sandbox and Sysbox](docs/n8n-assistant-sandbox.md)
- [OpenClaw: AI agent with Telegram and server access](docs/openclaw.md)
- [Open Terminal for Open WebUI](docs/open-terminal.md)
- [Keelflow: Moving from Flowise](docs/keelflow.md)
- [Ollama on multi-GPU hosts](docs/ollama-multi-gpu.md)
- [Open WebUI: SQLite or PostgreSQL](docs/open-webui-postgres.md)
- [Security notes: published ports and the firewall](docs/security.md)
- [Cloudflare Tunnel](cloudflare-instructions.md)
- [Caddy add-ons](caddy-addon/README.md)

## Troubleshooting

- **Sites don't load.** The server is usually out of RAM or CPU for the services you selected. Check `free -h` and `make monitor`, start with n8n only, and enable other services one by one. `make doctor` checks DNS, certificates and containers.
- **"Dangerous site" warning right after install.** Caddy briefly serves a temporary certificate while it gets one from Let's Encrypt. This normally clears within hours; if it lasts more than a day, check `make logs s=caddy` and your DNS records.
- **Monitoring freezes the system on WSL2.** `node-exporter` and `cAdvisor` traverse mounted filesystems to collect disk metrics; on WSL2 that includes Windows drives (`/mnt/c`, `/mnt/d`, ...) over the `9p`/`drvfs` protocol, where `stat()` hangs indefinitely and load average spikes above 900. Copy `docker-compose.override.yml.example` to `docker-compose.override.yml` and uncomment the `services:` block in the WSL2 section (gitignored, so `make update` won't overwrite it). Do **not** apply these flags on native Linux servers — they disable disk metrics in Grafana.
- **Docker images fail to pull.** Temporarily disable your VPN. `make update` retries a failed pull one service at a time. Services that still could not be updated but have an image on the server are started from it and listed at the end; finish them with `make pull && make restart`. If a service has no image at all, or the local n8n/OpenClaw images cannot be built, `make update` stops before restarting anything; run `make pull`, then `make update` again.
- **`make update` fails.** Force-sync with upstream. This discards local changes to tracked files:

  ```bash
  git config pull.rebase true && git fetch origin && git checkout main && git reset --hard "origin/main" && make update
  ```

## Credits

- Based on [local-ai-packaged](https://github.com/coleam00/local-ai-packaged) by coleam00 and the n8n team's [Self-hosted AI Starter Kit](https://github.com/n8n-io/self-hosted-ai-starter-kit)
- Community port: [n8n-installer-arch](https://github.com/ndrewpj/n8n-installer-arch) by [@ndrewpj](https://github.com/ndrewpj) for Arch, CachyOS and Manjaro

## Telemetry

The installer sends anonymous usage statistics through [Scarf](https://scarf.sh): event type, installer version, selected services, OS, a random installation ID, and the country Scarf derives from your IP. No personal data is collected. To opt out, set `SCARF_ANALYTICS=false` in `.env`.

## License

Apache License 2.0. See [LICENSE](LICENSE).
