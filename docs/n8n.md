# n8n: MCP, Code Node Libraries, Files and Monitoring

n8n runs in `queue` mode with Redis and Postgres; each worker gets its own task runner sidecar. Open `n8n.yourdomain.com` and create the owner account on first visit.

## n8n-MCP: n8n in Claude Code, Cursor and other AI IDEs

[n8n-MCP](https://github.com/czlonkowski/n8n-mcp) is a Model Context Protocol server that gives AI coding assistants (Claude Code, Cursor, Windsurf, VS Code Copilot) indexed access to every n8n node's documentation, property schemas and thousands of workflow templates - and, once you add an n8n API key, the ability to create and update workflows in your n8n instance straight from your IDE.

- **Endpoint**: `https://n8n-mcp.yourdomain.com/mcp`. Every request must send `Authorization: Bearer <N8N_MCP_AUTH_TOKEN>` - the token is on the Welcome Page - so a browser visit returns 401 by design.
- **Connect**: `npx -y mcp-remote https://n8n-mcp.yourdomain.com/mcp --header "Authorization: Bearer <token>"`, or keep the token out of your shell history and process list with `--header-file <path>` pointing at a file containing `Authorization: Bearer <token>`.
- **Managing workflows**: it starts in documentation-only mode. To also manage workflows, create an API key in n8n under Settings -> n8n API, set `N8N_API_KEY` in `.env` and run `make restart`. Note that outside n8n Enterprise an API key has full account access.
- **n8n's own MCP tools**: optionally set `N8N_MCP_ACCESS_TOKEN` (n8n Settings -> Instance-level MCP -> Connect -> API key; n8n 2.34+) for the tools only n8n's own MCP server provides - see `.env.example`.

## Using libraries in n8n Code nodes (v2.0+)

n8n v2.0 uses external task runners to execute JavaScript and Python code in Code nodes. This setup pre-configures the following libraries via `n8n/Dockerfile.runner` and `n8n/n8n-task-runners.json`:

**JavaScript libraries**:
- **`cheerio`**: For parsing and manipulating HTML/XML (e.g., web scraping).
- **`axios`**: A promise-based HTTP client for making requests to external APIs.
- **`moment`**: For parsing, validating, manipulating, and displaying dates/times.
- **`lodash`**: A utility library for common programming tasks (arrays, objects, strings, etc.).

## Pre-installed system tools (ffmpeg)

The custom n8n Docker image (`n8n/Dockerfile.n8n`) includes the following system-level tools:

- **`ffmpeg`**: A powerful multimedia framework for converting, recording, and streaming audio and video. Use it via the [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/) node in n8n workflows for tasks like:
  - Converting video/audio formats (e.g., MP4 to MP3)
  - Extracting audio from video files
  - Resizing or compressing media files
  - Generating thumbnails from videos

## Accessing files on the server

The installer creates a `shared` folder (by default, located in the same directory where you ran the installation script). This folder is accessible by the n8n application.
When you build automations in n8n that need to read or write files on your server, use the path `/data/shared` inside your n8n workflows. This path in n8n points to the `shared` folder on your server.

**n8n components that interact with the server's filesystem:**

- [Read/Write Files from Disk](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.filesreadwrite/)
- [Local File Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/) (To start workflows when files change)
- [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/) (To run command-line tools)

## Community workflows

The installer can import 300+ community workflows (AI agents and RAG, Gmail/Outlook, Notion/Airtable/Google Sheets, PDF/image/audio/video processing, Slack, social media, Telegram/WhatsApp/Discord bots, WordPress/WooCommerce). Import takes 20-30 minutes; you can run it later with `make import` (or `make import n=10` for the first N workflows).

## Monitoring n8n workflows with Grafana

Visit Grafana (`grafana.yourdomain.com`) to see dashboards monitoring your system's performance (data sourced from Prometheus).

The **n8n Monitoring** dashboard includes a *Workflow Executions* section, and four alert rules are pre-provisioned: *n8n workflow failed* (non-manual executions only, so testing in the editor does not page), *n8n workflow stalled* (an active workflow with no success for 24 hours), *n8n workflow has no recorded success* (active for 24 hours without ever succeeding since monitoring started) and *n8n metrics target down*. The 24-hour thresholds are global, so workflows that run less than daily will alert; tune them in `grafana/provisioning/alerting/n8n-workflows.yml`. Alerts follow Grafana's default notification policy, whose built-in email contact point delivers nothing without SMTP: create a contact point (Telegram, Slack, Email with `GF_SMTP_*`, ...) under **Alerting → Contact points** and select it in **Alerting → Notification policies**.
