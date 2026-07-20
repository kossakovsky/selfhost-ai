#!/bin/bash

# Preview available updates for Docker images without applying them
# This is a "dry-run" mode for the update process

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Load environment variables
load_env || exit 1

log_box "Update Preview (Dry Run)"
echo ""
echo -e "  ${CYAN}Checking for available updates...${NC}"
echo ""

# Function to get local image digest
get_local_digest() {
    local image="$1"
    docker image inspect "$image" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 | head -c 19
}

# Function to get remote image digest (without pulling)
get_remote_digest() {
    local image="$1"
    # Use docker manifest inspect to get remote digest without pulling
    docker manifest inspect "$image" 2>/dev/null | grep -m1 '"digest"' | cut -d'"' -f4 | head -c 19
}

# Function to check if an update is available
check_image_update() {
    local service_name="$1"
    local image="$2"

    # Skip if image is empty
    if [ -z "$image" ]; then
        return
    fi

    local local_digest=$(get_local_digest "$image")
    local remote_digest=$(get_remote_digest "$image")

    if [ -z "$local_digest" ]; then
        printf "  ${YELLOW}%-20s${NC} %-45s ${BLUE}[Not installed]${NC}\n" "$service_name" "$image"
        return
    fi

    if [ -z "$remote_digest" ]; then
        printf "  ${YELLOW}%-20s${NC} %-45s ${YELLOW}[Cannot check]${NC}\n" "$service_name" "$image"
        return
    fi

    if [ "$local_digest" != "$remote_digest" ]; then
        printf "  ${GREEN}%-20s${NC} %-45s ${GREEN}[Update available]${NC}\n" "$service_name" "$image"
        echo "                     Local:  $local_digest..."
        echo "                     Remote: $remote_digest..."
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        printf "  ${NC}%-20s${NC} %-45s ${NC}[Up to date]${NC}\n" "$service_name" "$image"
    fi
}

# Counter for available updates
UPDATES_AVAILABLE=0

# Get list of images from docker-compose
log_info "Scanning images from docker-compose.yml..."
echo ""

# Core services (always checked)
log_subheader "Core Services"
check_image_update "postgres" "pgvector/pgvector:pg${POSTGRES_VERSION:-17}"
check_image_update "redis" "valkey/valkey:8-alpine"
check_image_update "caddy" "caddy:2-alpine"

# Check n8n if profile is active
if is_profile_active "n8n"; then
    log_subheader "n8n Services"
    check_image_update "n8n" "docker.n8n.io/n8nio/n8n:stable"
    check_image_update "n8n-runner" "n8nio/runners:stable"
fi

# Check monitoring if profile is active
if is_profile_active "monitoring"; then
    log_subheader "Monitoring Services"
    check_image_update "grafana" "grafana/grafana:latest"
    check_image_update "prometheus" "prom/prometheus:latest"
    check_image_update "node-exporter" "prom/node-exporter:latest"
    check_image_update "cadvisor" "gcr.io/cadvisor/cadvisor:latest"
fi

# Check other common services
if is_profile_active "flowise"; then
    log_subheader "Flowise"
    check_image_update "flowise" "flowiseai/flowise:latest"
fi

if is_profile_active "open-webui"; then
    log_subheader "Open WebUI"
    check_image_update "open-webui" "ghcr.io/open-webui/open-webui:main"
fi

if is_profile_active "portainer"; then
    log_subheader "Portainer"
    check_image_update "portainer" "portainer/portainer-ce:latest"
fi

if is_profile_active "langfuse"; then
    log_subheader "Langfuse"
    check_image_update "langfuse-web" "langfuse/langfuse:latest"
    check_image_update "langfuse-worker" "langfuse/langfuse-worker:latest"
fi

if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    log_subheader "Ollama"
    check_image_update "ollama" "ollama/ollama:latest"
fi

if is_profile_active "invokeai-nvidia"; then
    log_subheader "InvokeAI"
    check_image_update "invokeai" "ghcr.io/invoke-ai/invokeai:latest"
elif is_profile_active "invokeai-amd"; then
    log_subheader "InvokeAI"
    check_image_update "invokeai" "ghcr.io/invoke-ai/invokeai:main-rocm"
elif is_profile_active "invokeai-cpu"; then
    log_subheader "InvokeAI"
    check_image_update "invokeai" "ghcr.io/invoke-ai/invokeai:main-cpu"
fi

if is_profile_active "qdrant"; then
    log_subheader "Qdrant"
    check_image_update "qdrant" "qdrant/qdrant:latest"
fi

if is_profile_active "searxng"; then
    log_subheader "SearXNG"
    check_image_update "searxng" "searxng/searxng:latest"
fi

if is_profile_active "databasus"; then
    log_subheader "Databasus"
    check_image_update "databasus" "databasus/databasus:latest"
fi

if is_profile_active "appsmith"; then
    log_subheader "Appsmith"
    check_image_update "appsmith" "appsmith/appsmith-ce:release"
fi

if is_profile_active "uptime-kuma"; then
    log_subheader "Uptime Kuma"
    check_image_update "uptime-kuma" "louislam/uptime-kuma:2"
fi

# Summary
log_divider
echo ""

if [ $UPDATES_AVAILABLE -gt 0 ]; then
    echo -e "  ${BRIGHT_GREEN}$UPDATES_AVAILABLE update(s) available!${NC}"
    echo ""
    echo -e "  ${WHITE}To apply updates, run:${NC}"
    echo -e "    ${CYAN}make update${NC}"
    echo ""
    echo -e "  ${DIM}Or manually:${NC}"
    echo -e "    ${DIM}docker compose -p localai pull${NC}"
    echo -e "    ${DIM}docker compose -p localai up -d${NC}"
else
    echo -e "  ${BRIGHT_GREEN}All images are up to date!${NC}"
fi

echo ""
