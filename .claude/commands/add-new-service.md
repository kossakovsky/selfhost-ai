# Add New Service: $ARGUMENTS

Add a new optional service called **$ARGUMENTS** to the n8n-install project.

## Naming Conventions

Derive these from `$ARGUMENTS`:
- `SERVICE_SLUG` = lowercase with hyphens, e.g., `my-service`
- `SERVICE_SLUG_UNDERSCORE` = lowercase with underscores, e.g., `my_service`
- `SERVICE_NAME_UPPER` = UPPERCASE with underscores, e.g., `MY_SERVICE`
- `SERVICE_NAME_TITLE` = Title Case, e.g., `MyService`

---

## STEP 1: docker-compose.yml

**File:** `docker-compose.yml`

### 1.1 Basic Service Definition

Add service block in `services:` section (maintain alphabetical order):

```yaml
  $ARGUMENTS:
    image: <org>/<image>:<tag>
    container_name: $ARGUMENTS
    profiles: ["$ARGUMENTS"]
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"
    environment:
      # Service-specific env vars
      SOME_VAR: "${SOME_VAR:-default}"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:<PORT>/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
    # volumes:
    #   - ${SERVICE_SLUG_UNDERSCORE}_data:/data
```

### 1.2 Caddy Environment Passthrough

Add to `caddy` service `environment:` section (if externally accessible):

```yaml
  caddy:
    environment:
      # ... existing vars ...
      ${SERVICE_NAME_UPPER}_HOSTNAME: "${${SERVICE_NAME_UPPER}_HOSTNAME}"
      # If using basic auth:
      ${SERVICE_NAME_UPPER}_USERNAME: "${${SERVICE_NAME_UPPER}_USERNAME}"
      ${SERVICE_NAME_UPPER}_PASSWORD_HASH: "${${SERVICE_NAME_UPPER}_PASSWORD_HASH}"
```

### 1.3 Named Volume (if persistent storage needed)

Add to top-level `volumes:` section:

```yaml
volumes:
  # ... existing ...
  ${SERVICE_SLUG_UNDERSCORE}_data:
```

### 1.4 Service Dependencies

If service requires database/cache, add `depends_on`:

```yaml
  $ARGUMENTS:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

Common dependencies:
- `postgres` - PostgreSQL database
- `redis` - Redis cache/queue
- `ollama` - Local LLM inference
- `minio` - S3-compatible object storage
- `clickhouse` - Analytics database (for Langfuse)

### 1.5 Database Initialization (if using PostgreSQL)

If service requires its own PostgreSQL database, add it to `scripts/databases.sh`:

```bash
# List of databases to create (add new services here)
INIT_DB_DATABASES=(
    "langfuse"
    "lightrag"
    "nocodb"
    "postiz"
    "waha"
    "new_data_base_name"  # Add your service here
)
```

**File:** `scripts/databases.sh`

This script:
- Runs automatically during install/update (BEFORE services start)
- Creates database if it doesn't exist (idempotent)
- Waits for PostgreSQL to be healthy first

**Important:** Database name should match what's configured in docker-compose.yml environment variables.

Example in docker-compose.yml:
```yaml
environment:
  DATABASE_URL: "postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/new_data_base_name"
  # OR individual vars:
  POSTGRES_HOST: postgres
  POSTGRES_DATABASE: new_data_base_name
```

### 1.6 Proxy Configuration (for outbound AI API calls)

If service makes HTTP requests to external AI APIs (OpenAI, Anthropic, Google, etc.), add proxy support:

```yaml
  $ARGUMENTS:
    environment:
      <<: *proxy-env  # Inherits HTTP_PROXY, HTTPS_PROXY, NO_PROXY
      # ... other env vars
```

The `x-proxy-env` anchor (defined at top of docker-compose.yml) provides:
- `HTTP_PROXY`, `HTTPS_PROXY`, `http_proxy`, `https_proxy` → `${GOST_PROXY_URL:-}`
- `NO_PROXY`, `no_proxy` → `${GOST_NO_PROXY:-}`

### 1.7 Healthcheck Proxy Bypass

**CRITICAL:** If using `<<: *proxy-env`, healthcheck MUST bypass proxy:

```yaml
healthcheck:
  test: ["CMD-SHELL", "http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= wget -qO- http://localhost:<PORT>/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
```

The `http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY=` prefix clears proxy vars for healthcheck only.

### 1.8 Multi-service Profiles

For services with multiple containers, use same profile for all:

```yaml
  $ARGUMENTS-worker:
    image: <org>/<image>-worker:<tag>
    container_name: $ARGUMENTS-worker
    profiles: ["$ARGUMENTS"]  # Same profile
    # ...

  $ARGUMENTS-web:
    image: <org>/<image>-web:<tag>
    container_name: $ARGUMENTS-web
    profiles: ["$ARGUMENTS"]  # Same profile
    # ...
```

For shared config, use YAML anchors:

```yaml
# At top of docker-compose.yml (x- prefix = extension, ignored by Docker)
x-$ARGUMENTS-common: &$ARGUMENTS-common
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy

# In service definitions:
  $ARGUMENTS-worker:
    <<: *$ARGUMENTS-common
    # ... rest of config

  $ARGUMENTS-web:
    <<: *$ARGUMENTS-common
    # ... rest of config
```

Examples in project:
- `langfuse` → langfuse-worker + langfuse-web + clickhouse + minio
- `ragflow` → ragflow + ragflow-mysql + ragflow-redis + ragflow-minio + ragflow-elasticsearch
- `monitoring` → prometheus + grafana + cadvisor + node-exporter

### 1.9 Hardware/GPU Profiles

For services with CPU/GPU variants, use mutually exclusive profiles:

```yaml
  # CPU variant
  $ARGUMENTS-cpu:
    <<: *service-$ARGUMENTS
    profiles: ["cpu"]

  # NVIDIA GPU variant
  $ARGUMENTS-gpu:
    <<: *service-$ARGUMENTS
    profiles: ["gpu-nvidia"]
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # AMD GPU variant
  $ARGUMENTS-gpu-amd:
    <<: *service-$ARGUMENTS
    image: <org>/<image>:rocm
    profiles: ["gpu-amd"]
    devices:
      - "/dev/kfd"
      - "/dev/dri"
```

Example: Ollama (ollama-cpu, ollama-gpu, ollama-gpu-amd)

---

## STEP 2: Caddyfile

**File:** `Caddyfile`

### 2.1 Basic Reverse Proxy

```caddyfile
# $ARGUMENTS
{$${SERVICE_NAME_UPPER}_HOSTNAME} {
    reverse_proxy $ARGUMENTS:<PORT>
}
```

### 2.2 With Basic Auth

```caddyfile
{$${SERVICE_NAME_UPPER}_HOSTNAME} {
    basic_auth {
        {$${SERVICE_NAME_UPPER}_USERNAME} {$${SERVICE_NAME_UPPER}_PASSWORD_HASH}
    }
    reverse_proxy $ARGUMENTS:<PORT>
}
```

### 2.3 Conditional Basic Auth (allow internal networks without auth)

```caddyfile
{$${SERVICE_NAME_UPPER}_HOSTNAME} {
    @protected not remote_ip 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10

    basic_auth @protected {
        {$${SERVICE_NAME_UPPER}_USERNAME} {$${SERVICE_NAME_UPPER}_PASSWORD_HASH}
    }
    reverse_proxy $ARGUMENTS:<PORT>
}
```

### 2.4 Special Protocols (non-standard port)

```caddyfile
# Example: Neo4j Bolt Protocol on port 7687
https://{$${SERVICE_NAME_UPPER}_HOSTNAME}:7687 {
    reverse_proxy $ARGUMENTS:7687
}
```
Note: Non-standard ports must be exposed in Caddy's `ports:` section in docker-compose.yml.

### 2.5 Static File Serving

```caddyfile
{$${SERVICE_NAME_UPPER}_HOSTNAME} {
    basic_auth {
        {$${SERVICE_NAME_UPPER}_USERNAME} {$${SERVICE_NAME_UPPER}_PASSWORD_HASH}
    }
    root * /srv/$ARGUMENTS
    file_server
    try_files {path} /index.html  # SPA fallback
}
```

---

## STEP 3: .env.example

**File:** `.env.example`

### 3.1 Hostname (in Caddy section)

```dotenv
${SERVICE_NAME_UPPER}_HOSTNAME=$ARGUMENTS.yourdomain.com
```

### 3.2 Credentials (if basic auth)

```dotenv
############
# [required]
# ${SERVICE_NAME_TITLE} credentials (for Caddy basic auth)
############
${SERVICE_NAME_UPPER}_USERNAME=
${SERVICE_NAME_UPPER}_PASSWORD=
${SERVICE_NAME_UPPER}_PASSWORD_HASH=
```

### 3.3 GOST_NO_PROXY (REQUIRED for ALL services)

**CRITICAL:** Add ALL new service container names to the comma-separated list to prevent internal Docker traffic from going through the proxy:

```dotenv
GOST_NO_PROXY=localhost,127.0.0.1,...existing...,$ARGUMENTS
```

This applies to ALL services, not just those using `<<: *proxy-env`. Internal service-to-service communication must bypass the proxy.

---

## STEP 4: scripts/03_generate_secrets.sh

**File:** `scripts/03_generate_secrets.sh`

### 4.1 VARS_TO_GENERATE Map (~line 75)

Add password/secret generation:

```bash
["${SERVICE_NAME_UPPER}_PASSWORD"]="password:32"
```

Available types:
- `password:32` - 32-char alphanumeric password
- `api_key:32` - Prefixed API key (sk_...)
- `base64:64` - Base64 encoded secret
- `jwt` - JWT secret
- `hex:32` - Hex string

### 4.2 EMAIL_VARS Array (~line 42)

If username should default to installer's email:

```bash
EMAIL_VARS=(
    # ... existing ...
    "${SERVICE_NAME_UPPER}_USERNAME"
)
```

### 4.3 SERVICES_NEEDING_HASH Array (~line 554)

**CRITICAL for Basic Auth:** Add service to generate bcrypt hash:

```bash
SERVICES_NEEDING_HASH=("PROMETHEUS" "SEARXNG" ... "${SERVICE_NAME_UPPER}")
```

This automatically:
1. Reads `${SERVICE_NAME_UPPER}_PASSWORD` from `.env`
2. Generates bcrypt hash via `docker exec caddy caddy hash-password`
3. Writes hash to `${SERVICE_NAME_UPPER}_PASSWORD_HASH` in `.env`

---

## STEP 5: scripts/04_wizard.sh

**File:** `scripts/04_wizard.sh`

### 5.1 Basic Addition (~line 40)

Add to `base_services_data` array:

```bash
"$ARGUMENTS" "${SERVICE_NAME_TITLE} (<short description>)"
```

### 5.2 Services with Additional Prompts

For services requiring extra input (like GOST asking for upstream proxy):

```bash
# After profile selection, add custom dialog
if [[ " ${selected_profiles[*]} " =~ " $ARGUMENTS " ]]; then
    CUSTOM_VALUE=$(whiptail --inputbox "Enter value for $ARGUMENTS:" 10 60 "" 3>&1 1>&2 2>&3)
    # Save to .env or use later
fi
```

See GOST implementation (~lines 206-242) as example.

### 5.3 Mutually Exclusive Services

For services that conflict (like Dify and Supabase):

```bash
# Remove conflicting service from selection
if [[ " ${selected_profiles[*]} " =~ " $ARGUMENTS " ]]; then
    selected_profiles=("${selected_profiles[@]/conflicting-service}")
fi
```

See Dify/Supabase exclusion (~lines 139-156) as example.

---

## STEP 5.5: scripts/05_configure_services.sh

**File:** `scripts/05_configure_services.sh`

For services needing runtime configuration beyond wizard:

```bash
# Configure $ARGUMENTS if active
if is_profile_active "$ARGUMENTS"; then
    log_info "Configuring $ARGUMENTS..."

    # Example: Generate config from template
    envsubst < ./$ARGUMENTS/config.template.yml > ./$ARGUMENTS/config.yml

    # Example: Handle mutual exclusion
    if is_profile_active "conflicting-service"; then
        log_warn "$ARGUMENTS and conflicting-service cannot run together"
        # Remove conflicting profile from COMPOSE_PROFILES
    fi
fi
```

Use cases:
- Token-based authentication (Cloudflare Tunnel)
- Mutual exclusion logic (Supabase vs Dify)
- Dynamic config file generation

---

## STEP 6: scripts/generate_welcome_page.sh

**File:** `scripts/generate_welcome_page.sh`

### 6.1 SERVICES_ARRAY Entry

Add conditional JSON block:

```bash
# ${SERVICE_NAME_TITLE}
if is_profile_active "$ARGUMENTS"; then
    SERVICES_ARRAY+=("    \"$ARGUMENTS\": {
      \"hostname\": \"$(json_escape "$${SERVICE_NAME_UPPER}_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$${SERVICE_NAME_UPPER}_USERNAME")\",
        \"password\": \"$(json_escape "$${SERVICE_NAME_UPPER}_PASSWORD")\"
      },
      \"extra\": {
        \"internal_api\": \"http://$ARGUMENTS:<PORT>\",
        \"docs\": \"<DOCS_URL>\"
      }
    }")
fi
```

### 6.2 JSON Structure Variants

**External service (with hostname):**
```bash
\"hostname\": \"$(json_escape "$${SERVICE_NAME_UPPER}_HOSTNAME")\",
```

**Internal-only service (no external access):**
```bash
\"hostname\": null,
```

**Credentials - username/password:**
```bash
\"credentials\": {
  \"username\": \"$(json_escape "$${SERVICE_NAME_UPPER}_USERNAME")\",
  \"password\": \"$(json_escape "$${SERVICE_NAME_UPPER}_PASSWORD")\"
}
```

**Credentials - API key only:**
```bash
\"credentials\": {
  \"api_key\": \"$(json_escape "$${SERVICE_NAME_UPPER}_API_KEY")\"
}
```

**Credentials - none (informational):**
```bash
\"credentials\": {
  \"note\": \"No authentication required\"
}
```

**Extra field examples:**
```bash
\"extra\": {
  \"internal_api\": \"http://$ARGUMENTS:<PORT>\",
  \"docs\": \"https://docs.example.com\",
  \"dashboard\": \"http://$ARGUMENTS:9000\",
  \"note\": \"Some helpful information\"
}
```

**Always use `json_escape "$VAR"`** to prevent JSON breaking from special characters.

### 6.3 QUICK_START_ARRAY (for first-run setup)

If service requires initial configuration:

```bash
if is_profile_active "$ARGUMENTS"; then
    QUICK_START_ARRAY+=("    \"$ARGUMENTS\": {
      \"title\": \"Configure ${SERVICE_NAME_TITLE}\",
      \"description\": \"Complete initial setup\",
      \"action\": \"Visit https://\${${SERVICE_NAME_UPPER}_HOSTNAME} to configure\"
    }")
fi
```

---

## STEP 6.5: scripts/07_final_report.sh

**File:** `scripts/07_final_report.sh`

For services with post-installation instructions:

```bash
if is_profile_active "$ARGUMENTS"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}${SERVICE_NAME_TITLE}${NC}: Visit dashboard to complete initial setup"
fi
```

Use for:
- First-time configuration steps
- Important security notices
- Links to documentation

---

## STEP 7: welcome/app.js

**File:** `welcome/app.js`

Add to `SERVICE_METADATA` object (~line 145):

```javascript
'$ARGUMENTS': {
    name: '${SERVICE_NAME_TITLE}',
    description: '<Short description ~50 chars>',
    icon: '<2-3 letter abbrev>',
    color: 'bg-[#<HEX>]',
    category: '<category>',
    docsUrl: '<DOCS_URL>'
},
```

### Categories

| Category     | Description         | Examples                                      |
| ------------ | ------------------- | --------------------------------------------- |
| `ai`         | AI/ML services      | Flowise, LangChain, Ollama, LightRAG          |
| `database`   | Data storage        | PostgreSQL, Qdrant, Weaviate, Neo4j           |
| `monitoring` | Observability       | Prometheus, Grafana, Langfuse                 |
| `tools`      | Utilities           | Gotenberg, Docling, LibreTranslate, PaddleOCR |
| `infra`      | Infrastructure      | Caddy, Redis, Gost, Portainer                 |
| `automation` | Workflow automation | n8n, Postiz                                   |

### Color Examples

```javascript
color: 'bg-blue-500'      // Tailwind named color
color: 'bg-[#FF6B35]'     // Custom hex color
color: 'bg-lime-500'      // Another named color
```

---

## STEP 8: README.md

**File:** `README.md`

### 8.1 What's Included Section

Add one-line description:

```markdown
✅ [**${SERVICE_NAME_TITLE}**](<DOCS_URL>) - <One-line description>
```

### 8.2 Quick Start and Usage Section

Add service URL (alphabetical order):

```markdown
- **${SERVICE_NAME_TITLE}:** `$ARGUMENTS.yourdomain.com` (<Brief description>)
```

---

## STEP 9: CHANGELOG.md

**File:** `CHANGELOG.md`

Add under the current month's `## [Month Year]` → `### Added` section (e.g., `## [December 2025]`):

```markdown
- **${SERVICE_NAME_TITLE}** - <Brief description of what it provides>
```

If no `### Added` section exists for the current month, create one.

---

## STEP 10: scripts/update_preview.sh (optional)

**File:** `scripts/update_preview.sh`

If service image should be tracked for updates:

```bash
if is_profile_active "$ARGUMENTS"; then
    check_image_update "<org>/<image>" "${SERVICE_NAME_UPPER}"
fi
```

---

## STEP 11: External Compose Files (for complex services like Supabase/Dify)

**Files:** `scripts/utils.sh`, `scripts/restart.sh`, `scripts/apply_update.sh`, `start_services.py`

For services with their own external docker-compose files (cloned from upstream repos):

### 11.1 Add getter function to utils.sh

```bash
# Get $ARGUMENTS compose file path if profile is active and file exists
# Usage: path=$(get_${SERVICE_SLUG_UNDERSCORE}_compose) && COMPOSE_FILES+=("-f" "$path")
get_${SERVICE_SLUG_UNDERSCORE}_compose() {
    local compose_file="$PROJECT_ROOT/$ARGUMENTS/docker/docker-compose.yml"
    if [ -f "$compose_file" ] && is_profile_active "$ARGUMENTS"; then
        echo "$compose_file"
        return 0
    fi
    return 1
}
```

### 11.2 Add to build_compose_files_array() in utils.sh

```bash
build_compose_files_array() {
    COMPOSE_FILES=("-f" "$PROJECT_ROOT/docker-compose.yml")
    # ... existing ...
    if path=$(get_${SERVICE_SLUG_UNDERSCORE}_compose); then
        COMPOSE_FILES+=("-f" "$path")
    fi
}
```

### 11.3 Add to start_services.py

Add functions similar to Supabase/Dify:
- `is_${SERVICE_SLUG_UNDERSCORE}_enabled()` - Check if profile is in COMPOSE_PROFILES
- `clone_${SERVICE_SLUG_UNDERSCORE}_repo()` - Clone upstream repo with sparse checkout
- `prepare_${SERVICE_SLUG_UNDERSCORE}_env()` - Copy/transform .env file
- `start_${SERVICE_SLUG_UNDERSCORE}()` - Start services if enabled
- Update `stop_all_services()` - Include compose file in down command (by file existence, not profile)

**Important:** `stop_all_services()` checks file existence only (not profile) to ensure cleanup when profile is removed.

Most services don't need this - only use for services that maintain their own docker-compose.yml upstream.

---

## VALIDATION

After all changes, validate:

```bash
# Docker Compose syntax
docker compose -p localai config --quiet

# Bash script syntax
bash -n scripts/03_generate_secrets.sh
bash -n scripts/04_wizard.sh
bash -n scripts/generate_welcome_page.sh
bash -n scripts/05_configure_services.sh
bash -n scripts/07_final_report.sh
```

---

## FINAL CHECKLIST

### Core (REQUIRED)
- [ ] `docker-compose.yml`: service with `profiles`, `container_name`, `logging`
- [ ] `docker-compose.yml`: caddy environment vars (if external)
- [ ] `Caddyfile`: reverse proxy block (if external)
- [ ] `.env.example`: hostname added
- [ ] `.env.example`: service added to `GOST_NO_PROXY` (ALL internal services must be listed)
- [ ] `scripts/03_generate_secrets.sh`: password in `VARS_TO_GENERATE`
- [ ] `scripts/04_wizard.sh`: service in `base_services_data`
- [ ] `scripts/generate_welcome_page.sh`: `SERVICES_ARRAY` entry
- [ ] `welcome/app.js`: `SERVICE_METADATA` entry
- [ ] `README.md`: description added
- [ ] `CHANGELOG.md`: entry added

### If Basic Auth
- [ ] `.env.example`: USERNAME, PASSWORD, PASSWORD_HASH vars
- [ ] `scripts/03_generate_secrets.sh`: username in `EMAIL_VARS`
- [ ] `scripts/03_generate_secrets.sh`: service in `SERVICES_NEEDING_HASH`
- [ ] `Caddyfile`: `basic_auth` block
- [ ] `docker-compose.yml`: USERNAME and PASSWORD_HASH passed to caddy

### If Outbound Proxy (AI API calls)
- [ ] `docker-compose.yml`: `<<: *proxy-env` in environment
- [ ] `docker-compose.yml`: healthcheck bypasses proxy

### If Database Required
- [ ] `docker-compose.yml`: `depends_on` with `condition: service_healthy`
- [ ] `scripts/databases.sh`: add database name to `INIT_DB_DATABASES` array

### If First-Run Setup Needed
- [ ] `scripts/generate_welcome_page.sh`: `QUICK_START_ARRAY` entry
- [ ] `scripts/07_final_report.sh`: post-install instructions

### If Special Configuration
- [ ] `scripts/04_wizard.sh`: custom prompts
- [ ] `scripts/05_configure_services.sh`: configuration logic

### If Multi-Container Service
- [ ] All containers use same profile
- [ ] YAML anchors for shared config

### If Hardware Variants (CPU/GPU)
- [ ] Mutually exclusive profiles (cpu, gpu-nvidia, gpu-amd)
- [ ] GPU resource reservations

### If External Compose File (Supabase/Dify style)
- [ ] `scripts/utils.sh`: `get_*_compose()` function added
- [ ] `scripts/utils.sh`: `build_compose_files_array()` updated
- [ ] `start_services.py`: `is_*_enabled()`, `clone_*_repo()`, `prepare_*_env()`, `start_*()` functions
- [ ] `start_services.py`: `stop_all_services()` includes compose file (by existence, not profile)
