# Changelog

## [Unreleased]

## [1.8.1] - 2026-07-23

### Added
- **Ollama** - Runtime tuning via `.env`: `OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_NUM_PARALLEL`, `OLLAMA_GPU_OVERHEAD` (in bytes), `OLLAMA_CONTEXT_LENGTH` and `OLLAMA_KV_CACHE_TYPE` were hardcoded (or unavailable) in `docker-compose.yml` and are now configurable, so multi-GPU hosts can keep more models resident and reserve VRAM for other tools sharing a GPU. The previously hardcoded values stay as the stack's defaults, and the two new variables are unset/zero by default so Ollama's stock behavior applies — existing installs are unaffected (#99).
- **Caddy** - `host.docker.internal` now resolves from the Caddy container (via `extra_hosts: host-gateway`), so custom `caddy-addon/site-*.conf` entries can reverse-proxy services running on the host machine.

### Changed
- **Docs** - README now documents the update-safe extension points (`caddy-addon/site-*.conf`, `docker-compose.override.yml`, `.env`), and `caddy-addon/README.md` gained a reverse-proxy example for stack-external services. The persistent-Caddy-entries mechanism requested in #100 already existed but was easy to miss (#100).

## [1.8.0] - 2026-07-20

### Added
- **Ollama / InvokeAI** - Optional GPU pinning for multi-GPU hosts. Set `OLLAMA_GPU_DEVICES` / `INVOKEAI_GPU_DEVICES` in `.env` (e.g. `OLLAMA_GPU_DEVICES=1,2`) to restrict a service to specific NVIDIA GPU IDs, so different workloads can own different GPUs. When the variable is empty (default), the existing count-based `*_GPU_COUNT` behavior is unchanged. NVIDIA profiles only (AMD variants use full `/dev/kfd`/`/dev/dri` passthrough); requires Docker Compose v2.24.4+ (#83).

### Removed
- **Hermes Agent** - **Breaking:** removed from the stack. An infrastructure-management agent should not run inside the environment it manages: it blurs the security boundary, couples the management layer to the workloads it controls, and creates a circular dependency (Hermes managing the Docker stack it lives in). On the next `make update`, the `hermes` profile is dropped from `COMPOSE_PROFILES` and the container is removed automatically; the data directory `./hermes` is left untouched so you can redeploy Hermes standalone with your own security model, and existing `HERMES_*` values in `.env` are kept under the preserved-variables section in case the standalone deployment needs them (delete them manually if not). If your `docker-compose.override.yml` still has a `hermes:` block, the updater warns you to delete it (#88).

### Fixed
- **Installer** - `make update` no longer silently deletes `.env` variables that are missing from `.env.example`. Custom user variables, uncommented opt-ins (e.g. `SCARF_ANALYTICS=false`), and the telemetry `INSTALLATION_ID` (which previously churned on every update) now survive updates: after the template pass, any variable found only in the old `.env` is re-appended under a `# --- Preserved user variables (not in template) ---` section, idempotently across repeated updates (#90).
- **Crawl4AI** - Fix the service being unreachable from other containers (n8n got `ECONNREFUSED` on `http://crawl4ai:11235`). Crawl4AI 0.9+ binds to `127.0.0.1` unless an API token is set, and upstream offers no bind-only override. A `CRAWL4AI_API_TOKEN` is now auto-generated and passed to the container, so it listens on the Docker network again; clients must send `Authorization: Bearer <token>` (token shown on the Welcome Page). Existing installs get the token generated on the next `make update` (#84).
- **Healthchecks** - Fix six services being reported `unhealthy` while running fine. LightRAG, ComfyUI, Appsmith, Gotenberg and Databasus used `wget`, which does not exist in their images; each now probes with a tool the image actually ships (curl for Appsmith/Gotenberg, python for ComfyUI/LightRAG, the native `databasus healthcheck` command for Databasus - verified against each upstream Dockerfile). PaddleOCR probed `/` (returns 404) and now probes `/health` (#85).
- **RagFlow** - Fix startup crash-loop (`nginx: [emerg] open() "/etc/nginx/conf.d/ragflow.conf" failed`). The real cause: the `ragflow_data:/ragflow` named volume masked the whole application directory with files from an older image, including a stale entrypoint. The volume and the obsolete custom nginx config are removed; the image now manages its own nginx config, and RagFlow state lives in its MySQL/Elasticsearch/MinIO/Redis services as upstream intends. The old `localai_ragflow_data` volume is left on disk (harmless; reclaim with `docker volume rm localai_ragflow_data` after a successful start) (#86).
- **python-runner** - Fix the default container restart-looping forever: the stock `main.py` printed one line and exited, and `restart: unless-stopped` kept restarting it, tripping `make doctor` warnings. The default script now stays alive with an idle loop, and the service uses `init: true` + `exec` so SIGTERM reaches Python directly and stops/updates are immediate instead of hanging until SIGKILL. Custom `main.py` files are preserved across updates as before (#87).

## [1.7.2] - 2026-07-13

### Fixed
- **Ollama / InvokeAI** - Fix `make update` resetting custom multi-GPU setups back to a single GPU. The NVIDIA GPU count was hardcoded as `count: 1` in `docker-compose.yml`, so any manual edit was wiped by the update's git reset. The count is now read from `.env` (`OLLAMA_GPU_COUNT` and `INVOKEAI_GPU_COUNT`, default `1`; set a number or `all`), which survives updates - the variables are added to existing `.env` files automatically on the next `make update` (#81).

## [1.7.1] - 2026-07-09

### Changed
- **Project renamed to Selfhost AI** - The repository moved from `kossakovsky/n8n-install` to [`kossakovsky/selfhost-ai`](https://github.com/kossakovsky/selfhost-ai) to reflect that the stack has grown well beyond n8n. GitHub redirects all old links and git remotes automatically, so existing installations keep working without changes. On the next `make update`, remotes still pointing at an old URL are repointed to the new one automatically (protocol preserved; fork remotes are never touched - only remotes targeting the canonical `kossakovsky/n8n-install` or the project's original name `kossakovsky/n8n-installer` are rewritten). The installer handles clones under all three directory names. Prefer updating in place (`make update`); if you migrate to a fresh clone instead, copy `.env` and the `supabase/`/`dify/` directories from the old checkout - Docker volumes are reused automatically, but secrets and external-stack data live in those files.

### Fixed
- **Installer** - The nested-clone cleanup in `install.sh` now verifies that the parent directory is actually a copy of this repository before removing anything. Previously, cloning into a same-named plain folder (e.g. `~/selfhost-ai/selfhost-ai`) made the installer delete the fresh clone (including `.env` with generated secrets on re-runs) and exit silently. The unreachable re-exec probe was replaced with an unconditional restart from the surviving outer copy.

## [1.7.0] - 2026-07-09

### Added
- **InvokeAI** - Professional Stable Diffusion studio with web UI, workflow editor, and REST API. Selectable NVIDIA/AMD/CPU hardware profiles (`invokeai-nvidia`, `invokeai-amd`, `invokeai-cpu`), protected by Caddy basic auth; models and outputs stored in `./invokeai` (#72)
- **Hermes Agent** - Autonomous AI agent platform by Nous Research (skills, persistent memory, MCP, multi-agent workflows) as an optional `hermes` profile. Web dashboard at `HERMES_HOSTNAME` (protected by Hermes's built-in basic auth with generated credentials) and OpenAI-compatible API at `HERMES_API_HOSTNAME` / `http://hermes:8642/v1` (Bearer `HERMES_API_SERVER_KEY`), so n8n workflows can call it like any OpenAI endpoint. Persistent data lives in `./hermes` (gitignored) for direct editing of `.env`, `config.yaml`, skills, and memories; configure an LLM provider via `docker compose -p localai run --rm hermes setup` (#71).
- **Cloudflare Tunnel** - Configurable transport protocol via `CLOUDFLARE_TUNNEL_PROTOCOL` in `.env`: `auto` (default, prefers QUIC with HTTP/2 fallback), `quic`, or `http2`. Set `http2` if your ISP or firewall blocks UDP and the tunnel is unstable (#69).

### Changed
- **Docker Compose** - Wrap all `${VARIABLE}` interpolations in double quotes to guard against YAML parsing issues with special characters in inline default values and keep the quoting style consistent across the file. No functional change: the rendered `docker compose config` output is identical (#70).

### Fixed
- **Installer** - Fail fast with a clear error when bcrypt hash generation fails during secret generation (affects all services behind Caddy basic auth). Previously an empty hash was written silently, which either broke Caddy config parsing on startup (taking down every service) or left the service behind a deny-all basic auth with no error surfaced.
- **Hermes Agent** - Add the missing `make update-preview` entry and Cloudflare Tunnel routing rows for the Hermes hostnames; `make doctor` now reports an error when the `hermes` profile is active but `HERMES_API_SERVER_KEY` is empty (the API server refuses to start without it, leaving the container half-dead).

## [1.6.0] - 2026-07-01

### Added
- **Ollama** - Optionally expose the Ollama API through Caddy under `OLLAMA_HOSTNAME`, protected by a generated Bearer token (`OLLAMA_CADDY_API_TOKEN`). Lets external tools reach locally-hosted models (native `/api/*` and OpenAI-compatible `/v1/*` endpoints); point DNS at the hostname to activate. Requests must send `Authorization: Bearer <token>`; unauthorized requests get `401`. A leaked token grants full control (including pulling/deleting models), so `make doctor` now reports an error if the hostname is set but the token is empty (#67).

## [1.5.2] - 2026-06-27

### Fixed
- **n8n** - Fix `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` thrown by `express-rate-limit` behind the Caddy reverse proxy. The compose file set `N8N_TRUST_PROXY: true`, which n8n does not recognize, so Express `trust proxy` stayed `false`. Replaced it with the correct `N8N_PROXY_HOPS` (number of reverse proxy hops, default `1`, overridable via `.env` for multi-proxy setups) (#65).

## [1.5.1] - 2026-06-17

### Fixed
- **Supabase** - Fix `make update` breaking existing databases by silently upgrading Postgres across major versions (e.g. `15.8.1.085` → `17.6.1.136`), which left `supabase-db` `unhealthy` and aborted the update. The installer now detects the major version of the data already on disk and pins `supabase/postgres` to a compatible tag after pulling upstream changes. Fresh installs continue to follow upstream (PG17); existing PG15 volumes stay on PG15 until you migrate manually (#64).

## [1.5.0] - 2026-05-17

### Fixed
- **cAdvisor** - Fix memory leak and uncontrolled CPU growth (up to ~3.5 GB RAM / 168% CPU on hosts with ~40+ containers) by pinning image to `v0.55.1`, adding resource limits (`mem_limit: 1g`, `cpus: "1.0"`), and tuning runtime flags (`--housekeeping_interval=10s`, `--docker_only=true`).
- **NocoDB** - Fix `Missing process handler for job type job` errors in n8n queue caused by NocoDB sharing the default Bull queue `jobs` with n8n in Redis db0. NocoDB is now isolated to Redis db1 via `NC_REDIS_URL=redis://redis:6379/1`.
- **Dify** - Fix install never starting (`could not translate host name "db_postgres"`) by activating Dify's bundled compose profiles (`postgresql`, `weaviate`) when starting the stack, and passing all Dify profiles when tearing it down so containers like `db_postgres` and `weaviate` get stopped cleanly (#61).
- **n8n** - Namespace Bull queue (`QUEUE_BULL_PREFIX=n8n`) to prevent neighbour conflicts, raise task runner timeout to 300s, and disable runner auto-shutdown to fix `Missing process handler` and `Task request timed out` errors. Default `N8N_RUNNERS_MAX_CONCURRENCY` raised 5 → 10. All four values configurable via `.env`.

## [1.4.3] - 2026-04-27

### Fixed
- **LightRAG** - Fix crash-loop (`TOKEN_SECRET must be explicitly set`) by generating `LIGHTRAG_TOKEN_SECRET` and passing it as `TOKEN_SECRET` to the container. Recent upstream releases require an explicit JWT signing secret whenever `AUTH_ACCOUNTS` is configured (#60).

## [1.4.2] - 2026-03-28

### Fixed
- **n8n** - Make `N8N_PAYLOAD_SIZE_MAX` configurable via `.env` (was hardcoded to 256, ignoring user overrides)
- **Uptime Kuma** - Fix healthcheck failure (`wget: not found`) by switching to Node.js-based check

## [1.4.1] - 2026-03-23

### Fixed
- **Supabase Storage** - Fix crash-loop (`Region is missing`) by adding missing S3 storage configuration variables (`REGION`, `GLOBAL_S3_BUCKET`, `STORAGE_TENANT_ID`) from upstream Supabase
- **Supabase** - Sync new environment variables to existing `supabase/docker/.env` during updates (previously only populated on first install)

## [1.4.0] - 2026-03-15

### Added
- **Uptime Kuma** - Self-hosted uptime monitoring with 90+ notification services
- **pgvector** - Switch PostgreSQL image to `pgvector/pgvector` for vector similarity search support

## [1.3.3] - 2026-02-27

### Fixed
- **Postiz** - Generate `postiz.env` file to prevent `dotenv-cli` crash in backend container (#40). Handles edge case where Docker creates the file as a directory, and quotes values to prevent misparses.

## [1.3.2] - 2026-02-27

### Fixed
- **Docker Compose** - Respect `docker-compose.override.yml` for user customizations (#44). All compose file assembly points now include the override file when present.

## [1.3.1] - 2026-02-27

### Fixed
- **Installer** - Skip n8n workflow import and worker configuration prompts when n8n profile is not selected

## [1.3.0] - 2026-02-27

### Added
- **Appsmith** - Low-code platform for building internal tools, dashboards, and admin panels

## [1.2.8] - 2026-02-27

### Fixed
- **Ragflow** - Fix nginx config mount path (`sites-available/default` → `conf.d/default.conf`) to resolve default "Welcome to nginx!" page (#41)

## [1.2.7] - 2026-02-27

### Fixed
- **Docker** - Limit parallel image pulls (`COMPOSE_PARALLEL_LIMIT=3`) to prevent `TLS handshake timeout` errors when many services are selected

## [1.2.6] - 2026-02-10

### Changed
- **ComfyUI** - Update Docker image to CUDA 12.8 (`cu128-slim`)

## [1.2.5] - 2026-02-03

### Fixed
- **n8n** - Use static ffmpeg binaries for Alpine/musl compatibility (fixes glibc errors)

## [1.2.4] - 2026-01-30

### Fixed
- **Postiz** - Fix `BACKEND_INTERNAL_URL` to use `localhost` instead of Docker hostname (internal nginx requires localhost)

## [1.2.3] - 2026-01-29

### Fixed
- **Gost proxy** - Add Telegram domains to `GOST_NO_PROXY` bypass list for n8n Telegram triggers

## [1.2.2] - 2026-01-26

### Fixed
- **Custom TLS** - Fix duplicate hostname error when using custom certificates. Changed architecture from generating separate site blocks to using a shared TLS snippet that all services import.

## [1.2.1] - 2026-01-16

### Added
- **Temporal** - Temporal server and UI for Postiz workflow orchestration (#33)

## [1.2.0] - 2026-01-12

### Added
- Changelog section on Welcome Page dashboard

## [1.1.0] - 2026-01-11

### Added
- **Custom TLS certificates** - Support for corporate/internal certificates via `caddy-addon/` mechanism
- New `make stop` and `make start` commands for stopping/starting all services without restart
- New `make setup-tls` command and `scripts/setup_custom_tls.sh` helper script for easy certificate configuration
- New `make git-pull` command for fork workflows - merges from upstream instead of hard reset

## [1.0.0] - 2026-01-07

### Added
- First official stable release

## [0.38.0] - 2026-01-04

### Fixed
- Gost proxy bypass for Supabase internal services

## [0.37.0] - 2026-01-02

### Added
- Workflow import command (`make import`)

## [0.36.0] - 2025-12-28

### Changed
- Postgresus renamed to Databasus with new Docker image `databasus/databasus:latest`
- Now supports PostgreSQL, MySQL, MariaDB, and MongoDB backups

## [0.35.0] - 2025-12-25

### Added
- Anonymous telemetry via Scarf (opt-out with `SCARF_ANALYTICS=false`)

## [0.34.0] - 2025-12-25

### Added
- NocoDB - Open source Airtable alternative with spreadsheet database interface

## [0.33.0] - 2025-12-22

### Fixed
- Static ffmpeg binary for n8n 2.1.0+ compatibility (apk removed upstream)

## [0.32.0] - 2025-12-21

### Fixed
- Healthcheck proxy bypass for localhost connections

## [0.31.0] - 2025-12-20

### Added
- Gost proxy - HTTP/HTTPS proxy for AI services outbound traffic (geo-bypass)

## [0.30.0] - 2025-12-11

### Added
- Doctor diagnostics - System health checks and troubleshooting
- Update preview - Preview changes before applying updates
- Wizard service groups for better organization

## [0.29.0] - 2025-12-12

### Fixed
- Open-webui healthcheck with longer start_period

## [0.28.0] - 2025-12-11

### Added
- Welcome page dashboard with service credentials and quick start

## [0.27.0] - 2025-12-09

### Fixed
- n8n v2.0 migration review issues

## [0.26.0] - 2025-12-09

### Added
- n8n 2.0 support with worker-runner sidecar pattern
- Makefile for common project commands (`make install`, `make update`, `make logs`, etc.)

### Changed
- Task execution now uses dedicated runners per worker
- Workers and runners generated dynamically via `scripts/generate_n8n_workers.sh`

## [0.25.0] - 2025-12-08

### Changed
- n8n Dockerfile updated to use stable version 2.0.0

## [0.24.0] - 2025-11-09

### Added
- Docling - Universal document converter to Markdown/JSON

## [0.23.0] - 2025-11-01

### Added
- LightRAG - Graph-based RAG with knowledge graphs

## [0.22.0] - 2025-10-29

### Added
- RAGFlow - Deep document understanding RAG engine

## [0.21.0] - 2025-10-15

### Added
- WAHA - WhatsApp HTTP API (NOWEB engine)

## [0.20.0] - 2025-08-28

### Added
- Postgresus - PostgreSQL backups & monitoring

## [0.19.0] - 2025-08-28

### Added
- LibreTranslate - Self-hosted translation API (50+ languages)

## [0.18.0] - 2025-08-27

### Added
- PaddleOCR - OCR API Server

## [0.17.0] - 2025-08-19

### Added
- Postiz - Social publishing platform

## [0.16.0] - 2025-08-15

### Added
- Python Runner - Custom Python code execution environment

## [0.15.0] - 2025-08-15

### Added
- RAGApp - Open-source RAG UI + API

## [0.14.0] - 2025-08-13

### Added
- Cloudflare Tunnel - Zero-trust secure access

## [0.13.0] - 2025-08-07

### Added
- ComfyUI - Node-based Stable Diffusion UI

## [0.12.0] - 2025-08-07

### Added
- Portainer - Docker management UI

## [0.11.0] - 2025-08-06

### Added
- Gotenberg - Document conversion API (internal use)

## [0.10.0] - 2025-08-06

### Added
- Dify - AI Application Development Platform with LLMOps

## [0.9.0] - 2025-06-17

### Added
- Qdrant Caddy reverse proxy configuration

## [0.8.0] - 2025-05-28

### Added
- Monitoring stack - Prometheus, Grafana, cAdvisor, node-exporter

## [0.7.0] - 2025-05-26

### Added
- Neo4j - Graph database

## [0.6.0] - 2025-05-24

### Added
- Weaviate - Vector database with API Key Auth

## [0.5.0] - 2025-05-22

### Added
- Qdrant - Vector database

## [0.4.0] - 2025-05-15

### Added
- Ollama - Local LLM inference

## [0.3.0] - 2025-05-15

### Added
- Letta - Agent Server & SDK

## [0.2.0] - 2025-05-09

### Added
- Interactive service selection wizard using whiptail
- Profile-based service management via Docker Compose profiles

## [0.1.0] - 2025-04-18

### Added
- Langfuse - LLM observability and analytics platform
- Initial fork from coleam00/local-ai-packager with enhanced service support

---

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
