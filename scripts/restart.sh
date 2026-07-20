#!/bin/bash
# =============================================================================
# restart.sh - Restart all services
# =============================================================================
# Restarts all Docker Compose services including dynamically generated
# worker/runner compose files and external service stacks.
#
# Handles compose files via build_compose_files_array() from utils.sh:
#   - docker-compose.yml (main)
#   - docker-compose.n8n-workers.yml (if exists and n8n profile active)
#   - docker-compose.ollama-gpu-devices.yml (if gpu-nvidia profile active and OLLAMA_GPU_DEVICES set)
#   - docker-compose.invokeai-gpu-devices.yml (if invokeai-nvidia profile active and INVOKEAI_GPU_DEVICES set)
#   - supabase/docker/docker-compose.yml (if exists and supabase profile active)
#   - dify/docker/docker-compose.yaml (if exists and dify profile active)
#   - docker-compose.override.yml (if exists, user overrides with highest precedence)
#
# Usage: bash scripts/restart.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

cd "$PROJECT_ROOT"

# Load environment to check active profiles
load_env

PROJECT_NAME="localai"

# Time to wait for external services (Supabase, Dify) to initialize before starting main stack
EXTERNAL_SERVICE_INIT_DELAY=10

# Build compose files array (sets global COMPOSE_FILES)
build_compose_files_array

# Ensure postiz.env exists if Postiz is enabled (required for volume mount)
# This is a safety net for cases where restart runs without start_services.py
# (e.g., git pull + make restart instead of make update)
if is_profile_active "postiz"; then
    if [ -d "$PROJECT_ROOT/postiz.env" ]; then
        log_warning "postiz.env exists as a directory (created by Docker). Removing and recreating as file."
        rm -rf "$PROJECT_ROOT/postiz.env"
        touch "$PROJECT_ROOT/postiz.env"
    elif [ ! -f "$PROJECT_ROOT/postiz.env" ]; then
        log_warning "postiz.env not found, creating empty file. Run 'make update' to generate full config."
        touch "$PROJECT_ROOT/postiz.env"
    fi
fi

log_info "Restarting services..."
log_info "Using compose files: ${COMPOSE_FILES[*]}"

# Stop all services using ALL compose files (including external stacks)
# This ensures clean shutdown of everything before restart
docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" down

# Start services in correct order (matching start_services.py behavior)
# NOTE: External stacks (Supabase, Dify) must be started SEPARATELY because their
# compose files use relative paths for volumes/configs. When combined with main
# docker-compose.yml via -f flags, the relative paths resolve incorrectly.
# Solution: Start external stacks first from their own directories, then start main stack.

if is_profile_active "supabase"; then
    SUPABASE_COMPOSE="$PROJECT_ROOT/supabase/docker/docker-compose.yml"
    if [ -f "$SUPABASE_COMPOSE" ]; then
        log_info "Starting Supabase services..."
        docker compose -p "$PROJECT_NAME" -f "$SUPABASE_COMPOSE" up -d
        log_info "Waiting for Supabase to initialize..."
        sleep "$EXTERNAL_SERVICE_INIT_DELAY"
    fi
fi

if is_profile_active "dify"; then
    DIFY_COMPOSE="$PROJECT_ROOT/dify/docker/docker-compose.yaml"
    if [ -f "$DIFY_COMPOSE" ]; then
        log_info "Starting Dify services..."
        docker compose -p "$PROJECT_NAME" -f "$DIFY_COMPOSE" up -d
        log_info "Waiting for Dify to initialize..."
        sleep "$EXTERNAL_SERVICE_INIT_DELAY"
    fi
fi

# Build main compose files (exclude external stacks that were started separately)
MAIN_COMPOSE_FILES=("-f" "$PROJECT_ROOT/docker-compose.yml")
if path=$(get_n8n_workers_compose); then
    MAIN_COMPOSE_FILES+=("-f" "$path")
fi
if path=$(get_ollama_gpu_devices_compose); then
    MAIN_COMPOSE_FILES+=("-f" "$path")
fi
if path=$(get_invokeai_gpu_devices_compose); then
    MAIN_COMPOSE_FILES+=("-f" "$path")
fi
OVERRIDE_COMPOSE="$PROJECT_ROOT/docker-compose.override.yml"
if [ -f "$OVERRIDE_COMPOSE" ]; then
    MAIN_COMPOSE_FILES+=("-f" "$OVERRIDE_COMPOSE")
fi

# Start main services
log_info "Starting main services..."
docker compose -p "$PROJECT_NAME" "${MAIN_COMPOSE_FILES[@]}" up -d

log_success "Services restarted successfully!"
