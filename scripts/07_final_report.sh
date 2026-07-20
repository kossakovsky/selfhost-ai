#!/bin/bash
# =============================================================================
# 07_final_report.sh - Post-installation summary and credentials display
# =============================================================================
# Generates and displays the final installation report after all services
# are running.
#
# Actions:
#   - Generates welcome page data (via generate_welcome_page.sh)
#   - Displays Welcome Page URL and credentials
#   - Shows next steps for configuring individual services
#   - Provides guidance for first-run setup of n8n, Portainer, Flowise, etc.
#
# The Welcome Page serves as a central dashboard with all service credentials
# and access URLs, protected by basic auth.
#
# Usage: bash scripts/07_final_report.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Load environment variables from .env file
load_env || exit 1

# Generate welcome page data
if [ -f "$SCRIPT_DIR/generate_welcome_page.sh" ]; then
    log_info "Generating welcome page..."
    bash "$SCRIPT_DIR/generate_welcome_page.sh" || log_warning "Failed to generate welcome page"
fi

# Helper function to print a divider line
print_line() {
    echo -e "${DIM}${GREEN}$(printf '%.0s-' {1..70})${NC}"
}

# Helper function to print a credential row
print_credential() {
    local label="$1"
    local value="$2"
    printf "  ${CYAN}%-12s${NC} ${WHITE}%s${NC}\n" "$label:" "$value"
}

# Helper function to print section header
print_section() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${BRIGHT_GREEN}  $title${NC}"
    echo -e "  ${DIM}$(printf '%.0s-' {1..40})${NC}"
}

# Clear screen for clean presentation
clear

# Header
log_box "Installation/Update Complete"

# --- Welcome Page Section ---
print_section "Welcome Page"
echo ""
echo -e "  ${WHITE}All your service credentials are available here:${NC}"
echo ""
print_credential "URL" "https://${WELCOME_HOSTNAME:-welcome.${USER_DOMAIN_NAME}}"
print_credential "Username" "${WELCOME_USERNAME:-<not_set>}"
print_credential "Password" "${WELCOME_PASSWORD:-<not_set>}"
echo ""
echo -e "  ${DIM}The Welcome Page shows all installed services with their${NC}"
echo -e "  ${DIM}hostnames, credentials, and internal URLs.${NC}"

# --- Next Steps Section ---
print_section "Next Steps"
echo ""
echo -e "  ${WHITE}1.${NC} Visit your Welcome Page to view all credentials"
echo -e "     ${CYAN}https://${WELCOME_HOSTNAME:-welcome.${USER_DOMAIN_NAME}}${NC}"
echo ""
echo -e "  ${WHITE}2.${NC} Store the Welcome Page credentials securely"
echo ""
echo -e "  ${WHITE}3.${NC} Configure services as needed:"
if is_profile_active "appsmith"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Appsmith${NC}: Create admin account on first login (may take a few minutes to start)"
fi
if is_profile_active "n8n"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}n8n${NC}: Complete first-run setup with your email"
fi
if is_profile_active "portainer"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Portainer${NC}: Create admin account on first login"
fi
if is_profile_active "databasus"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Databasus${NC}: Create account and configure backup schedules"
fi
if is_profile_active "flowise"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Flowise${NC}: Register and create your account"
fi
if is_profile_active "open-webui"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Open WebUI${NC}: Register your account"
fi
if is_profile_active "nocodb"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}NocoDB${NC}: Create your account on first login"
fi
if is_profile_active "postiz"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Postiz${NC}: Create your account on first login"
fi
if is_profile_active "uptime-kuma"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Uptime Kuma${NC}: Create your account on first login"
fi
if is_profile_active "gost"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Gost Proxy${NC}: Routing AI traffic through external proxy"
fi
if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Ollama API${NC}: To expose externally, point DNS at ${OLLAMA_HOSTNAME:-<OLLAMA_HOSTNAME>} and send 'Authorization: Bearer <token>' (see Welcome Page)"
fi
if is_profile_active "crawl4ai"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}Crawl4AI${NC}: Internal API at http://crawl4ai:11235 - requests must send 'Authorization: Bearer <token>' (token on Welcome Page)"
fi
if is_profile_active "invokeai-nvidia" || is_profile_active "invokeai-amd" || is_profile_active "invokeai-cpu"; then
    echo -e "     ${GREEN}*${NC} ${WHITE}InvokeAI${NC}: Open the Model Manager on first visit and download a starter model before generating images"
fi
echo ""
echo -e "  ${WHITE}4.${NC} Run ${CYAN}make doctor${NC} if you experience any issues"

# --- Footer ---
echo ""
print_line
echo ""
echo -e "  ${BRIGHT_GREEN}Thank you for using Selfhost AI!${NC}"
echo ""
print_line
echo ""
