#!/bin/bash

# System diagnostics script for Selfhost AI
# Checks DNS, SSL, containers, disk space, memory, and configuration

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Counters for summary
ERRORS=0
WARNINGS=0
OK=0

# Wrapper functions that also count results
count_ok() {
    print_ok "$1"
    OK=$((OK + 1))
}

count_warning() {
    print_warning "$1"
    WARNINGS=$((WARNINGS + 1))
}

count_error() {
    print_error "$1"
    ERRORS=$((ERRORS + 1))
}

# Header
log_box "Selfhost AI System Diagnostics"

# Check if .env file exists
log_subheader "Configuration"

if [ -f "$ENV_FILE" ]; then
    count_ok ".env file exists"

    # Load environment variables
    load_env

    # Check required variables
    if [ -n "$USER_DOMAIN_NAME" ]; then
        count_ok "USER_DOMAIN_NAME is set: $USER_DOMAIN_NAME"
    else
        count_error "USER_DOMAIN_NAME is not set"
    fi

    if [ -n "$LETSENCRYPT_EMAIL" ]; then
        count_ok "LETSENCRYPT_EMAIL is set"
    else
        count_warning "LETSENCRYPT_EMAIL is not set (SSL certificates may not work)"
    fi

    if [ -n "$COMPOSE_PROFILES" ]; then
        count_ok "Active profiles: $COMPOSE_PROFILES"
    else
        count_warning "No service profiles are active"
    fi

    # Ollama API exposure: when OLLAMA_HOSTNAME points at a real domain, the Caddy
    # bearer-token gate needs a non-empty OLLAMA_CADDY_API_TOKEN to be usable. With
    # an empty token the matcher becomes "Bearer " (trailing space); Go trims
    # trailing whitespace from header values, so no request can ever match and the
    # endpoint rejects everything with 401 (fail-closed, but non-functional).
    if [ -n "$OLLAMA_HOSTNAME" ] && [ "$OLLAMA_HOSTNAME" != "yourdomain.com" ] && [[ "$OLLAMA_HOSTNAME" != *".yourdomain.com" ]]; then
        if [ -n "$OLLAMA_CADDY_API_TOKEN" ]; then
            count_ok "OLLAMA_CADDY_API_TOKEN is set (Ollama API is token-protected)"
        else
            count_error "OLLAMA_HOSTNAME is set but OLLAMA_CADDY_API_TOKEN is empty — the Ollama endpoint will reject all requests (401). Run 'make update' to regenerate the token."
        fi
    fi

    # Crawl4AI 0.9+ binds loopback only when CRAWL4AI_API_TOKEN is empty, so the
    # container looks "Up" while other containers get connection refused. A
    # healthcheck cannot catch this (localhost works either way), so check here.
    if is_profile_active "crawl4ai"; then
        if [ -n "$CRAWL4AI_API_TOKEN" ]; then
            count_ok "CRAWL4AI_API_TOKEN is set (Crawl4AI listens on the Docker network)"
        else
            count_error "crawl4ai profile is active but CRAWL4AI_API_TOKEN is empty — Crawl4AI binds loopback only and other containers cannot reach it. Run 'make update' to generate the token."
        fi
    fi

else
    count_error ".env file not found at $ENV_FILE"
    print_info "Run 'make install' to set up the environment."
    exit 1
fi

# Check Docker
log_subheader "Docker"

if command -v docker &> /dev/null; then
    count_ok "Docker is installed"

    if docker info &> /dev/null; then
        count_ok "Docker daemon is running"
    else
        count_error "Docker daemon is not running or not accessible"
    fi
else
    count_error "Docker is not installed"
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    count_ok "Docker Compose is available"
else
    count_warning "Docker Compose is not available"
fi

# Check disk space
log_subheader "Disk Space"

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

if [ "$DISK_USAGE" -lt 80 ]; then
    count_ok "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available)"
elif [ "$DISK_USAGE" -lt 90 ]; then
    count_warning "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available) - Consider freeing space"
else
    count_error "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available) - Critical!"
fi

# Check Docker disk usage
DOCKER_DISK=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1)
if [ -n "$DOCKER_DISK" ]; then
    print_info "Docker using: $DOCKER_DISK"
fi

# Check memory
log_subheader "Memory"

if command -v free &> /dev/null; then
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')

    if [ "$MEM_PERCENT" -lt 80 ]; then
        count_ok "Memory usage: ${MEM_PERCENT}% (${MEM_AVAIL} available of ${MEM_TOTAL})"
    elif [ "$MEM_PERCENT" -lt 90 ]; then
        count_warning "Memory usage: ${MEM_PERCENT}% (${MEM_AVAIL} available)"
    else
        count_error "Memory usage: ${MEM_PERCENT}% - High memory pressure!"
    fi
else
    print_info "Memory info not available (free command not found)"
fi

# Check containers
log_subheader "Containers"

RUNNING=$(docker ps -q 2>/dev/null | wc -l)
TOTAL=$(docker ps -aq 2>/dev/null | wc -l)

print_info "$RUNNING of $TOTAL containers running"

# Check for containers with high restart counts
HIGH_RESTARTS=0
while read -r line; do
    if [ -n "$line" ]; then
        name=$(echo "$line" | cut -d'|' -f1)
        restarts=$(echo "$line" | cut -d'|' -f2)
        if [ "$restarts" -gt 3 ]; then
            count_warning "$name has restarted $restarts times"
            HIGH_RESTARTS=$((HIGH_RESTARTS + 1))
        fi
    fi
done < <(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | while read container; do
    name=$(echo "$container" | cut -d'|' -f1)
    restarts=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "0")
    echo "$name|$restarts"
done)

if [ "$HIGH_RESTARTS" -eq 0 ]; then
    count_ok "No containers with excessive restarts"
fi

# Check unhealthy containers
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null)
if [ -n "$UNHEALTHY" ]; then
    for container in $UNHEALTHY; do
        count_error "Container $container is unhealthy"
    done
else
    count_ok "No unhealthy containers"
fi

# Check DNS resolution
log_subheader "DNS Resolution"

check_dns() {
    local hostname="$1"
    local varname="$2"

    if [ -z "$hostname" ] || [ "$hostname" == "yourdomain.com" ] || [[ "$hostname" == *".yourdomain.com" ]]; then
        return
    fi

    if host "$hostname" &> /dev/null; then
        count_ok "$varname ($hostname) resolves"
    else
        count_error "$varname ($hostname) does not resolve"
    fi
}

# Only check if we have a real domain
if [ -n "$USER_DOMAIN_NAME" ] && [ "$USER_DOMAIN_NAME" != "yourdomain.com" ]; then
    check_dns "$N8N_HOSTNAME" "N8N_HOSTNAME"
    check_dns "$GRAFANA_HOSTNAME" "GRAFANA_HOSTNAME"
    check_dns "$PORTAINER_HOSTNAME" "PORTAINER_HOSTNAME"
    check_dns "$WELCOME_HOSTNAME" "WELCOME_HOSTNAME"
else
    print_info "Skipping DNS checks (no domain configured)"
fi

# Check SSL (Caddy)
log_subheader "SSL/Caddy"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "caddy"; then
    count_ok "Caddy container is running"

    # Check if Caddy can reach the config
    if docker exec caddy caddy validate --config /etc/caddy/Caddyfile &> /dev/null; then
        count_ok "Caddyfile is valid"
    else
        count_warning "Caddyfile validation failed (may be fine if using default)"
    fi
else
    count_warning "Caddy container is not running"
fi

# Check key services
log_subheader "Key Services"

check_service() {
    local container="$1"
    local port="$2"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        count_ok "$container is running"
    else
        if is_profile_active "$container" || [ "$container" == "postgres" ] || [ "$container" == "redis" ] || [ "$container" == "caddy" ]; then
            count_error "$container is not running (but expected)"
        fi
    fi
}

check_service "postgres" "5432"
check_service "redis" "6379"
check_service "caddy" "80"

if is_profile_active "n8n"; then
    check_service "n8n" "5678"
fi

if is_profile_active "monitoring"; then
    check_service "grafana" "3000"
    check_service "prometheus" "9090"
fi

# Summary
log_box "Summary"
echo ""
echo -e "  ${GREEN}OK:${NC}       ${BOLD}$OK${NC}"
echo -e "  ${YELLOW}Warnings:${NC} ${BOLD}$WARNINGS${NC}"
echo -e "  ${RED}Errors:${NC}   ${BOLD}$ERRORS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "  ${BG_RED}${WHITE} ISSUES FOUND ${NC}"
    echo -e "  ${RED}Please review the errors above and take action.${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "  ${BG_YELLOW}${WHITE} MOSTLY HEALTHY ${NC}"
    echo -e "  ${YELLOW}System is functional with some warnings.${NC}"
    exit 0
else
    echo -e "  ${BG_GREEN}${WHITE} HEALTHY ${NC}"
    echo -e "  ${GREEN}All checks passed successfully!${NC}"
    exit 0
fi
