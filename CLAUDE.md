# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Selfhost AI** (repository `selfhost-ai`, formerly `n8n-install`), a Docker Compose-based installer that provides a comprehensive self-hosted environment for n8n workflow automation and numerous AI/automation services. The installer includes an interactive wizard, automated secret generation, and integrated HTTPS via Caddy.

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
- `scripts/generate_n8n_workers.sh`: Generates dynamic worker/runner compose file and the Prometheus n8n targets file
- `scripts/generate_ollama_instances.sh`: Generates extra Ollama instances compose file (multi-GPU)
- `scripts/update.sh`: Update orchestrator (syncs with origin and updates images)
- `scripts/update_preview.sh`: Preview available updates without applying (dry-run)
- `scripts/doctor.sh`: System diagnostics (DNS, SSL, containers, disk, memory)
- `scripts/apply_update.sh`: Applies updates after git sync
- `scripts/docker_cleanup.sh`: Removes unused Docker resources (used by `make clean`)
- `scripts/download_top_workflows.sh`: Downloads community n8n workflows
- `scripts/import_workflows.sh`: Imports workflows from `n8n/backup/workflows/` into n8n (used by `make import`)
- `scripts/restart.sh`: Restarts services with proper compose file handling (used by `make restart`)
- `scripts/setup_custom_tls.sh`: Configures custom TLS certificates (used by `make setup-tls`); supports `--remove` to revert to Let's Encrypt
- `scripts/setup_sysbox.sh`: Installs Sysbox (`sysbox-runc`) for the n8n Assistant sandbox runner; called by `05_configure_services.sh` when the `n8n-sandbox` profile is active
- `start_services.py`: Python orchestrator for service startup order, builds Docker images, handles external services (Supabase/Dify cloning, env preparation, startup), generates SearXNG secret key, stops existing containers. Uses `python-dotenv` (`dotenv_values`).

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

The update flow (`scripts/update.sh`) similarly orchestrates: git fetch + reset → service selection → `apply_update.sh` → restart. During updates, `03_generate_secrets.sh` adds new variables from `.env.example` without regenerating existing ones (preserves user-set values). Note the `--update` flag `apply_update.sh` passes is **not parsed** - the behavior is unconditional, and code that needs to tell a fresh install from an upgrade tests `${#existing_env_vars[@]} -gt 0` instead (see the `DB_MIGRATION_VARS` and `OPEN_WEBUI_DATABASE` blocks).

**Git update modes**: Default is `reset` (hard reset to origin). Set `GIT_MODE=merge` in `.env` for fork workflows (merges from upstream instead of hard reset). The `make git-pull` command uses merge mode. Git branch support is explicit: `GIT_SUPPORTED_BRANCHES=("main" "develop")` in `git.sh`; unknown branches warn and fall back to `main`.

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
6. **scripts/databases.sh**: If service uses PostgreSQL, add database name to `INIT_DB_DATABASES` array. Database creation is idempotent (checks existence before creating). Note: Postiz also requires `temporal` and `temporal_visibility` databases.
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
   [2.6.0]: https://github.com/kossakovsky/selfhost-ai/compare/v2.5.3...v2.6.0
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
  - **JavaScript runner**: packages installed via `pnpm add` in Dockerfile.runner; allowlist in `n8n-task-runners.json` (`NODE_FUNCTION_ALLOW_EXTERNAL`, `NODE_FUNCTION_ALLOW_BUILTIN`); default packages: `cheerio`, `axios`, `moment`, `lodash`
  - **Python runner**: also configured in `n8n-task-runners.json`; uses `/opt/runners/task-runner-python/.venv/bin/python` with `N8N_RUNNERS_STDLIB_ALLOW: "*"` and `N8N_RUNNERS_EXTERNAL_ALLOW: "*"`
- Workflows can access the host filesystem via `/data/shared` (mapped to `./shared`)
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` allows Code nodes to access environment variables

### Ollama Multi-Instance (multi-GPU)

- `OLLAMA_INSTANCE_COUNT` in `.env` (default 1, max 8) drives `scripts/generate_ollama_instances.sh`, which writes `docker-compose.ollama-instances.yml` (auto-generated, gitignored)
- **Template profile pattern**, same as the n8n workers: `docker-compose.yml` defines `ollama-instance-template` and `ollama-instance-template-amd` with `profiles: ["ollama-template"]` (never activated directly)
- **The templates deliberately carry no `deploy:` block.** Compose *appends* `deploy.resources.reservations.devices` across `extends`, so a count-based reservation on the template would leak an extra, arbitrary GPU into every instance that pins specific device IDs. Do not add one.
- Instance 1 is the stock `ollama` container and is never modified; count 1 generates nothing and **removes** a stale file, which otherwise resurrects the old instance set after a downscale
- Per-instance tuning uses `OLLAMA<N>_*` variables emitted as nested defaults (`${OLLAMA2_KEEP_ALIVE:-${OLLAMA_KEEP_ALIVE:-}}`), so users tune `.env` and restart without regenerating
- NVIDIA pins via `deploy.…device_ids`; AMD pins via `HIP_VISIBLE_DEVICES`/`ROCR_VISIBLE_DEVICES` (ROCm passes all devices through)
- All instances share the `ollama_storage` volume, so models are downloaded once; only instance 1 has a model-pull job
- No published ports and no Caddy block for extra instances - they are internal (`ollama2:11434`); `caddy-addon/site-*.conf` is the documented extension point
- The generator is invoked unconditionally from `05_configure_services.sh`, which covers install and `make update`, and self-heals a stale file after a hardware-profile switch

### n8n Assistant sandbox (`n8n-sandbox` profile)

- Upstream n8n-sandbox-service as three services in `docker-compose.yml`: one-shot `sandbox-certs` (mTLS bootstrap into the `n8n_sandbox_tls` volume, skips when certs exist), `sandbox-api` (HTTP 8080 + gRPC 9090) and the Docker-in-Docker `sandbox-runner-1`. No ports, no Caddy block; n8n reaches `sandbox-api` by service name. **The cert SANs are the service names `sandbox-api` / `sandbox-runner-1` - do not rename them.** Exactly one runner by design.
- All three images share `N8N_SANDBOX_VERSION` (default `latest`, like most images here). The runner pulls the sandbox image into its inner Docker on first use, and deliberately has **no volume** for that inner Docker: a persisted cache would keep an old sandbox image while `make update` moves api and runner forward. The cost is one ~330 MB pull after every recreate.
- Three secrets, each referenced on both sides from one `.env` var: `N8N_SANDBOX_API_KEY` (n8n's `N8N_SANDBOX_SERVICE_API_KEY` = api's `SANDBOX_API_KEYS`), `N8N_SANDBOX_RUNNER_REGISTRATION_TOKEN`, `N8N_SANDBOX_RUNNER_API_KEY`.
- The n8n env anchor carries `N8N_INSTANCE_AI_SANDBOX_ENABLED` (written `true`/`false` by `05_configure_services.sh` from the profile), the sandbox URL/key, `N8N_INSTANCE_AI_SEARXNG_URL` (set to `http://searxng:8080` while `searxng` is active, cleared otherwise; a custom value is left alone) and `N8N_ENABLED_MODULES` (**empty by default** - `instance-ai` is default-on in n8n, and an unknown module name stops n8n from booting, so never default it to a name). There is deliberately no `depends_on` from `n8n` to `sandbox-api`: a dependency on a profile-gated service breaks compose when the profile is off. The model/API key is configured in the n8n UI, not in compose.
- Runner isolation: `runtime: "${N8N_SANDBOX_RUNNER_RUNTIME:-runc}"` + `privileged: "${N8N_SANDBOX_RUNNER_PRIVILEGED:-false}"` (compose casts the interpolated string to boolean). `05_configure_services.sh` runs `setup_sysbox.sh`; on success it writes `sysbox-runc`/`false`, otherwise it asks (`wt_yesno`, default No) before writing `runc`/`true`, and drops the profile on No. It also loads `br_netfilter` in both modes (the sandbox egress policy needs it) and persists it in `/etc/modules-load.d/n8n-sandbox.conf`. Without root, 05 exits 1 for this profile instead of configuring a runner that cannot start.
- `setup_sysbox.sh` must stay non-interactive and must not restart Docker: the `sysbox-ce` package refuses to install while any container exists unless `/etc/docker/daemon.json` already has pretty-printed `bip` and `default-address-pools` keys, so the script pre-seeds them with Docker's current values via `jq --indent 4` and then the package only registers the runtime and SIGHUPs dockerd. Hosts with a custom Docker network setup (`-b`/`--bridge`/`--bip`/`--default-address-pool`/`--fixed-cidr` flags; `bridge`, `fixed-cidr`, `fixed-cidr-v6` or `ipv6: true` in daemon.json; no `docker0`) are rejected instead of guessed at. An already installed Sysbox is re-tested with a container on every run, never trusted from `dpkg` state alone. `jq` is not installed by 01/02 - only this script may rely on it, after its own apt step.
- `make doctor` errors when `.env` says `sysbox-runc` but Docker lacks the runtime, and warns while the runner is privileged.

### Open Terminal (`open-terminal` profile)

- Single service `open-terminal` (`ghcr.io/open-webui/open-terminal`, tag from `OPEN_TERMINAL_VERSION`, default `latest`; only the full image - `latest` or a release tag like `0.12.5` - supports multi-user and runtime installs, the `*-slim`/`*-alpine`/`openshift` variants do not). No ports, no Caddy block; Open WebUI reaches `http://open-terminal:8000`. The wizard drops the profile when `open-webui` is not selected, same pattern as `n8n-sandbox` / `n8n`.
- **The connection is configured only in the Open WebUI Admin UI** (Admin Settings → Integrations → Open Terminal, URL + `OPEN_TERMINAL_API_KEY`). Do not pre-seed it via `TERMINAL_SERVER_CONNECTIONS`: Open WebUI seeds that key into its DB only when the key is missing, i.e. on a brand-new database, and a connection without `config.access_grants` is admin-only anyway. Open WebUI proxies every request server-side and sends `X-User-Id`, which multi-user mode maps to a Linux account under `/home` - the volume must be `/home`, not `/home/user`.
- **Never add `OPEN_TERMINAL_ALLOWED_DOMAINS` to the compose file.** The entrypoint distinguishes unset (full egress) from set-but-empty (drop all outbound) and runs `sudo iptables` under `set -e`, which needs `NET_ADMIN`; an interpolated `${VAR:-}` would crash the container. Egress filtering is a `docker-compose.override.yml` job together with `cap_add: [NET_ADMIN]`.
- Never mount `docker.sock`: the entrypoint auto-joins the socket's group and the agent's shell would control the host daemon. The server process runs as `user` with passwordless sudo, so no `cap_drop` (apt, useradd and sudo need CHOWN/SETUID/SETGID/DAC_OVERRIDE). Provisioned per-user accounts are plain `useradd` users **without sudo**; only `OPEN_TERMINAL_MULTI_USER=false` gives the chat the sudo-capable shell, and only then are the startup package lists optional. The boundary is the network and the Open WebUI access grants. Healthcheck uses `curl` against the unauthenticated `/docs`.
- `05_configure_services.sh` refuses a `slim`/`alpine`/`openshift` variant tag (bare or `-suffixed`) while `OPEN_TERMINAL_MULTI_USER=true`: those entrypoints ignore the multi-user and package variables, so every user would silently share one shell.

### Monitoring (Prometheus + Grafana)

- n8n metrics are enabled in the `x-n8n` anchor: `N8N_METRICS` plus `N8N_METRICS_INCLUDE_MESSAGE_EVENT_BUS_METRICS` / `_WORKFLOW_ID_LABEL` / `_WORKFLOW_NAME_LABEL` / `_WORKFLOW_INFO`. They expose `n8n_workflow_{started,success,failed,cancelled}_total{workflow_id,workflow_name}` and the `n8n_workflow_info` / `n8n_active_workflow_info` id-to-name gauges (leader main only). The alerts and recording rules also use `n8n_workflow_execution_duration_seconds{status,mode,workflow_id}`, which is on by default (`N8N_METRICS_INCLUDE_WORKFLOW_EXECUTION_DURATION`); turning it off silently disables them. Setting `N8N_METRICS_PREFIX` would break every panel and alert
- **In queue mode the workflow counters and the duration histogram are emitted by `n8n` main**, which finalises every top-level execution; workers only report sub-workflow executions, node events and their own process metrics. Panels and rules therefore aggregate across instances (`sum by (...)`) and must not filter on `$instance`
- Scrape targets are not static: `generate_n8n_workers.sh` writes `prometheus/targets/n8n.json` (gitignored) with the `n8n:5678` main target and one `n8n-worker-N:5678` per worker, each group carrying its `job` label, and `prometheus.yml` reads it via `file_sd_configs`. The generator runs unconditionally from `05_configure_services.sh` and removes the file when the n8n profile is inactive, so a monitoring-only install has no n8n targets and no permanently-down alert. Metrics are served on the queue-health port (`QUEUE_HEALTH_CHECK_PORT`, default 5678; 5679 is the task broker)
- `prometheus/rules/*.yml` holds recording rules keyed on `workflow_id` (`n8n:workflow_success:increase5m`, `n8n:workflow_last_success_timestamp_seconds`); names are joined at query time from `n8n_active_workflow_info`, so renames are followed. The whole `prometheus/` directory is bind-mounted read-only to `/etc/prometheus`
- Grafana's datasource, dashboards and alert rules are file-provisioned from `grafana/provisioning/`; contact points and notification policies are not, and no SMTP is configured. The Prometheus datasource has the fixed `uid: Prometheus` that dashboards and alert rules reference - keep them in sync. Grafana cannot change the uid of an existing datasource, so `main.yml` deletes it by name (`deleteDatasources`) and recreates it on every start; pre-1.10.0 installations had a random uid and crash-looped without this. Use `$__rate_interval`, never a fixed range window, in range queries
- No Alertmanager: alert rules are Grafana-managed (`grafana/provisioning/alerting/n8n-workflows.yml`); a malformed file stops Grafana from starting. `make doctor` checks that Grafana/Prometheus run, that the targets file matches `N8N_WORKER_COUNT` and that Prometheus loaded the `n8n-workflows` rule group without errors

### Caddy Reverse Proxy

- Automatically obtains Let's Encrypt certificates when `LETSENCRYPT_EMAIL` is set
- Hostnames are passed via environment variables (e.g., `N8N_HOSTNAME`, `FLOWISE_HOSTNAME`)
- Basic auth uses bcrypt hashes generated by `scripts/03_generate_secrets.sh` via Caddy's hash command
- Never add `ports:` to services in docker-compose.yml; let Caddy handle all external access
- **Caddy Addons** (`caddy-addon/`): Extend Caddy config without modifying the main Caddyfile. Files matching `site-*.conf` are auto-imported (gitignored, user-created). TLS is controlled via `tls-snippet.conf` (all service blocks use `import service_tls`). See `caddy-addon/README.md` for details.
- Custom TLS certificates go in `certs/` directory (gitignored), referenced as `/etc/caddy/certs/` inside the container

### External Compose Files (Supabase/Dify)

Complex services like Supabase and Dify maintain their own upstream docker-compose files:
- `start_services.py` handles cloning repos, preparing `.env` files, and starting services
- Each external service needs: `is_*_enabled()`, `clone_*_repo()`, `prepare_*_env()`, `start_*()` functions in `start_services.py`
- `scripts/utils.sh` provides `get_*_compose()` getter functions and `build_compose_files_array()` includes them
- `stop_all_services()` in `start_services.py` checks compose file existence (not profile) to ensure cleanup when a profile is removed
- All external compose files use the same project name (`-p localai`) so containers appear together
- **`docker-compose.override.yml`**: User customizations file (gitignored). Both `start_services.py` and `build_compose_files_array()` in `utils.sh` auto-detect and include it last (highest precedence). Users can override any service property without modifying tracked files.

### Secret Generation

The `scripts/03_generate_secrets.sh` script:
- Generates random passwords, JWT secrets, API keys, and encryption keys
- Creates bcrypt password hashes using Caddy's `hash-password` command
- Preserves existing user-provided values in `.env`
- Supports different secret types via `VARS_TO_GENERATE` map: `password:32`, `jwt`, `api_key`, `base64:64`, `hex:32`
- Preserves existing values on every run; the `--update` flag passed during updates is accepted but never parsed

### Utility Functions (scripts/utils.sh)

Source with: `source "$(dirname "$0")/utils.sh" && init_paths`

Key functions:
- `is_profile_active "myservice"` - Check if profile is enabled
- `read_env_var "VAR_NAME"` / `write_env_var "VAR_NAME" "value"` - .env manipulation
- `load_env` - Source .env file to make variables available
- `update_compose_profiles "profile1,profile2"` - Update COMPOSE_PROFILES in .env
- `remove_compose_profile "$list" "profile"` - Print a comma list without one profile (space-tolerant)
- `gen_password 32` / `gen_hex 64` / `gen_base64 64` - Secret generation
- `generate_bcrypt_hash "password"` - Create Caddy-compatible bcrypt hash (uses Caddy binary)
- `json_escape "string"` - Escape string for JSON output
- `wt_input`, `wt_password`, `wt_yesno`, `wt_msg` - Whiptail dialog wrappers
- `wt_checklist`, `wt_radiolist`, `wt_menu` - Whiptail selection dialogs
- `wt_parse_choices "$result" array_name` - Parse quoted checklist output safely
- `log_info`, `log_success`, `log_warning`, `log_error` - Logging functions
- `log_header`, `log_subheader`, `log_divider`, `log_box` - Formatted output
- `print_ok`, `print_error`, `print_warning`, `print_info` - Doctor output helpers
- `get_real_user` / `get_real_user_home` - Get actual user even under sudo
- `backup_preserved_dirs` / `restore_preserved_dirs` - Directory preservation for git updates
- `cleanup_legacy_n8n_workers` - Remove old n8n worker containers from previous naming convention
- `get_n8n_workers_compose` / `get_supabase_compose` / `get_dify_compose` - Get compose file path if profile active AND file exists
- `get_ollama_instances_compose` / `get_open_webui_postgres_compose` - Conditional compose overrides (multi-Ollama, Open WebUI on Postgres)
- `harden_supabase_gateway_bind` - Keep the Supabase API gateway bound to loopback (issue #108)
- `cleanup_stale_ollama_instances` - Remove Ollama instance containers above the configured count
- `build_compose_files_array` - Build global `COMPOSE_FILES` array with all active compose files (main + external)

### Service Profiles

Common profiles:
- `n8n`: n8n workflow automation (includes main app, worker, runner, and import services)
- `flowise`: Flowise AI agent builder
- `monitoring`: Prometheus, Grafana, cAdvisor, node-exporter
- `langfuse`: Langfuse observability (includes ClickHouse, MinIO, worker, web)
- `cpu`, `gpu-nvidia`, `gpu-amd`: Ollama hardware profiles (mutually exclusive)
- `invokeai-nvidia`, `invokeai-amd`, `invokeai-cpu`: InvokeAI hardware profiles (mutually exclusive)
- `cloudflare-tunnel`: Cloudflare Tunnel for zero-trust access (see `cloudflare-instructions.md`)
- `supabase`: Supabase BaaS (external compose, cloned at runtime; mutually exclusive with `dify`)
- `dify`: Dify AI platform (external compose, cloned at runtime; mutually exclusive with `supabase`)
- `gost`: HTTP/HTTPS proxy for routing AI service outbound traffic
- `python-runner`: Internal Python execution environment (no external access)
- `n8n-sandbox`: n8n Assistant code-execution sandbox (requires `n8n`; internal only, see below)
- `open-terminal`: Open Terminal execution sandbox for Open WebUI agents (requires `open-webui`; internal only, see below)
- `searxng`, `letta`, `lightrag`, `libretranslate`, `crawl4ai`, `docling`, `waha`, `comfyui`, `paddleocr`, `ragapp`, `gotenberg`, `postiz`, `n8n-mcp`: Additional optional services

## Architecture Patterns

### Docker Compose YAML Anchors

`docker-compose.yml` defines reusable anchors at the top:
- `x-logging: &default-logging` - `json-file` with `max-size: 1m`, `max-file: 1`
- `x-proxy-env: &proxy-env` - HTTP/HTTPS proxy vars from `GOST_PROXY_URL`/`GOST_NO_PROXY`
- `x-n8n: &service-n8n` - Full n8n service definition (reused by workers via `extends`)
- `x-ollama: &service-ollama` - Ollama service definition (reused by CPU/GPU variants)
- `x-init-ollama: &init-ollama` - Ollama model pre-puller (auto-pulls `qwen2.5:7b-instruct-q4_K_M` and `nomic-embed-text`)
- `x-n8n-worker-runner: &service-n8n-worker-runner` - Runner template for worker generation

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
- Always wrap `${VAR}` interpolations in `docker-compose.yml` in double quotes: `"${VAR:-default}"`

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
  HTTP_PROXY: "${GOST_PROXY_URL:-}"
  HTTPS_PROXY: "${GOST_PROXY_URL:-}"
  NO_PROXY: "${GOST_NO_PROXY:-}"

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

### Restart Behavior

`scripts/restart.sh` stops all services first, then starts external stacks (Supabase/Dify) separately before the main stack (10s delay between). This is required because external compose files use relative volume paths that resolve from their own directory.

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

## File Locations

- Shared files accessible by n8n: `./shared` (mounted as `/data/shared` in n8n)
- n8n backup/workflows: `n8n/backup/workflows/` (mounted as `/backup` in n8n containers)
- n8n storage: Docker volume `localai_n8n_storage`
- Flowise storage: `~/.flowise` on host (mounted from user's home directory, not a named volume)
- Custom TLS certificates: `certs/` (gitignored, mounted as `/etc/caddy/certs/`)
- Caddy addon configs: `caddy-addon/site-*.conf` (gitignored, auto-imported)
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
bash -n scripts/generate_ollama_instances.sh
bash -n scripts/apply_update.sh
bash -n scripts/update.sh
bash -n scripts/install.sh
bash -n scripts/restart.sh
bash -n scripts/doctor.sh
bash -n scripts/setup_custom_tls.sh
bash -n scripts/setup_sysbox.sh
bash -n scripts/docker_cleanup.sh
```

### Full Testing

When modifying installer scripts:
1. Test on a clean Ubuntu 24.04 LTS system (minimum 4GB RAM / 2 CPU)
2. Verify all profile combinations work
3. Check that `.env` is properly generated
4. Confirm final report displays correct URLs and credentials
5. Test update script preserves custom configurations
