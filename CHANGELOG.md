# Changelog

## [Unreleased]

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
