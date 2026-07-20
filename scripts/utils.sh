#!/bin/bash
# =============================================================================
# utils.sh - Shared utilities for Selfhost AI scripts
# =============================================================================
# Common functions and utilities used across all installation scripts.
#
# Provides:
#   - Path initialization (init_paths): Sets SCRIPT_DIR, PROJECT_ROOT, ENV_FILE
#   - Logging functions: log_info, log_success, log_warning, log_error
#   - .env manipulation: read_env_var, write_env_var, load_env
#   - Whiptail wrappers: wt_input, wt_yesno, require_whiptail
#   - Validation helpers: require_command, require_file, ensure_file_exists
#   - Profile management: is_profile_active, update_compose_profiles
#   - Doctor output helpers: print_ok, print_warning, print_error
#   - Directory preservation: backup_preserved_dirs, restore_preserved_dirs
#
# Usage: source "$(dirname "$0")/utils.sh" && init_paths
# =============================================================================

#=============================================================================
# CONSTANTS
#=============================================================================
DOMAIN_PLACEHOLDER="yourdomain.com"

#=============================================================================
# WHIPTAIL THEME (NEWT_COLORS)
#=============================================================================
# Solarized Dark theme with blue/cyan accents
# Format: element=foreground,background
# Colors: black, red, green, yellow, blue, magenta, cyan, white
# Prefix with "bright" for bright variants (e.g., brightblue)
export NEWT_COLORS='
root=white,black
border=blue,black
window=white,black
shadow=black,black
title=brightblue,black
button=black,blue
actbutton=black,cyan
compactbutton=white,black
checkbox=blue,black
actcheckbox=black,cyan
entry=cyan,black
disentry=gray,black
label=white,black
listbox=white,black
actlistbox=black,blue
sellistbox=cyan,black
actsellistbox=black,cyan
textbox=white,black
acttextbox=blue,black
emptyscale=black,black
fullscale=blue,black
helpline=blue,black
roottext=blue,black
'

#=============================================================================
# PATH INITIALIZATION
#=============================================================================

# Initialize standard paths - call at start of each script
# WARNING: Must be called directly from script top-level, NOT from within functions.
#          BASH_SOURCE[1] refers to the script that sourced utils.sh.
# Usage: source utils.sh && init_paths
init_paths() {
    # BASH_SOURCE[1] = the script that called this function (not utils.sh itself)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    ENV_FILE="$PROJECT_ROOT/.env"
}

#=============================================================================
# LOGGING (Simplified)
#=============================================================================

# Internal logging function
_log() {
    local level="$1"
    local message="$2"
    echo ""
    echo "[$level] $(date +%H:%M:%S): $message"
}

log_info() {
    _log "INFO" "$1"
}

log_success() {
    _log "OK" "$1"
}

log_warning() {
    _log "WARN" "$1"
}

log_error() {
    _log "ERROR" "$1" >&2
}

# Display a header for major sections
# Usage: log_header "Section Title"
log_header() {
    local message="$1"
    local width=60
    local padding=$(( (width - ${#message} - 2) / 2 ))
    local pad_left=$(printf '%*s' "$padding" '' | tr ' ' '=')
    local pad_right=$(printf '%*s' "$((width - ${#message} - 2 - padding))" '' | tr ' ' '=')

    echo ""
    echo ""
    echo -e "${BRIGHT_GREEN}${pad_left}${NC} ${BOLD}${WHITE}${message}${NC} ${BRIGHT_GREEN}${pad_right}${NC}"
}

# Display a sub-header for sections
# Usage: log_subheader "Sub Section"
log_subheader() {
    local message="$1"
    echo ""
    echo -e "${CYAN}--- ${message} ---${NC}"
}

# Display a divider line
# Usage: log_divider
log_divider() {
    echo ""
    echo -e "${DIM}${GREEN}$(printf '%.0s-' {1..60})${NC}"
}

# Display text in a box (for important messages)
# Usage: log_box "Important message"
log_box() {
    local message="$1"
    local len=${#message}
    local border=$(printf '%*s' "$((len + 4))" '' | tr ' ' '=')

    echo ""
    echo -e "${BRIGHT_GREEN}+${border}+${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}  ${BOLD}${WHITE}${message}${NC}  ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}+${border}+${NC}"
}

#=============================================================================
# COLOR OUTPUT (for diagnostics and previews)
#=============================================================================
# Basic colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color / Reset

# Text styles
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Bright colors
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_CYAN='\033[1;36m'

# Background colors (for badges/labels)
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'

print_ok() {
    echo ""
    echo -e "  ${GREEN}[OK]${NC} $1"
}

print_error() {
    echo ""
    echo -e "  ${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo ""
    echo -e "  ${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo ""
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

#=============================================================================
# PROGRESS INDICATORS
#=============================================================================

# Spinner animation frames
SPINNER_FRAMES=('|' '/' '-' '\')
SPINNER_PID=""

# Start spinner with message
# Usage: start_spinner "Loading..."
start_spinner() {
    local message="$1"
    local i=0

    # Don't start if not in terminal or already running
    [[ ! -t 1 ]] && return
    [[ -n "$SPINNER_PID" ]] && return

    (
        while true; do
            printf "\r  ${GREEN}${SPINNER_FRAMES[$i]}${NC} ${message}  "
            i=$(( (i + 1) % 4 ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    disown
}

# Stop spinner and clear line
# Usage: stop_spinner
stop_spinner() {
    [[ -z "$SPINNER_PID" ]] && return

    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""

    # Clear the spinner line
    printf "\r%*s\r" 80 ""
}

# Show step progress (e.g., Step 3/7)
# Usage: show_step 3 7 "Installing Docker"
show_step() {
    local current=$1
    local total=$2
    local description="$3"

    echo ""
    echo -e "${BRIGHT_GREEN}[${current}/${total}]${NC} ${BOLD}${description}${NC}"
    echo -e "${DIM}$(printf '%.0s.' {1..50})${NC}"
}

# Show a simple progress bar
# Usage: show_progress 50 100 "Downloading"
show_progress() {
    local current=$1
    local total=$2
    local label="${3:-Progress}"
    local width=40
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    local bar_filled=$(printf '%*s' "$filled" '' | tr ' ' '#')
    local bar_empty=$(printf '%*s' "$empty" '' | tr ' ' '-')

    printf "\r  ${label}: ${GREEN}[${bar_filled}${GRAY}${bar_empty}${GREEN}]${NC} ${WHITE}%3d%%${NC}" "$percent"
}

# Complete progress bar with message
# Usage: complete_progress "Download complete"
complete_progress() {
    local message="${1:-Done}"
    printf "\r%*s\r" 80 ""
    echo -e "  ${GREEN}[OK]${NC} ${message}"
}

#=============================================================================
# ENVIRONMENT MANAGEMENT
#=============================================================================

# Load .env file safely
# Usage: load_env [env_file_path]
load_env() {
    local env_file="${1:-$ENV_FILE}"
    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found: $env_file"
        return 1
    fi
    set -a
    source "$env_file"
    set +a
}

# Read a variable from .env file
# Usage: value=$(read_env_var "VAR_NAME" [env_file])
read_env_var() {
    local var_name="$1"
    local env_file="${2:-$ENV_FILE}"
    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        grep "^${var_name}=" "$env_file" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//"
    fi
}

# Write/update a variable in .env file (with automatic .bak cleanup)
# Usage: write_env_var "VAR_NAME" "value" [env_file]
write_env_var() {
    local var_name="$1"
    local var_value="$2"
    local env_file="${3:-$ENV_FILE}"

    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        sed -i.bak "\|^${var_name}=|d" "$env_file"
        rm -f "${env_file}.bak"
    fi
    echo "${var_name}=\"${var_value}\"" >> "$env_file"
}

# Check if a Docker Compose profile is active
# IMPORTANT: Requires COMPOSE_PROFILES to be set before calling (via load_env or direct assignment)
# Usage: is_profile_active "n8n" && echo "n8n is active"
is_profile_active() {
    local profile="$1"
    [[ -n "$COMPOSE_PROFILES" && ",$COMPOSE_PROFILES," == *",$profile,"* ]]
}

# Get n8n workers compose file path if profile is active and file exists
# Usage: path=$(get_n8n_workers_compose) && COMPOSE_FILES+=("-f" "$path")
get_n8n_workers_compose() {
    local compose_file="$PROJECT_ROOT/docker-compose.n8n-workers.yml"
    if [ -f "$compose_file" ] && is_profile_active "n8n"; then
        echo "$compose_file"
        return 0
    fi
    return 1
}

# Get Ollama GPU pinning compose file path if the gpu-nvidia profile is active
# and OLLAMA_GPU_DEVICES has a non-empty value (requires load_env first)
# Usage: path=$(get_ollama_gpu_devices_compose) && COMPOSE_FILES+=("-f" "$path")
get_ollama_gpu_devices_compose() {
    local compose_file="$PROJECT_ROOT/docker-compose.ollama-gpu-devices.yml"
    if [ -f "$compose_file" ] && is_profile_active "gpu-nvidia" && [ -n "${OLLAMA_GPU_DEVICES:-}" ]; then
        echo "$compose_file"
        return 0
    fi
    return 1
}

# Get InvokeAI GPU pinning compose file path if the invokeai-nvidia profile is
# active and INVOKEAI_GPU_DEVICES has a non-empty value (requires load_env first)
# Usage: path=$(get_invokeai_gpu_devices_compose) && COMPOSE_FILES+=("-f" "$path")
get_invokeai_gpu_devices_compose() {
    local compose_file="$PROJECT_ROOT/docker-compose.invokeai-gpu-devices.yml"
    if [ -f "$compose_file" ] && is_profile_active "invokeai-nvidia" && [ -n "${INVOKEAI_GPU_DEVICES:-}" ]; then
        echo "$compose_file"
        return 0
    fi
    return 1
}

# Get Supabase compose file path if profile is active and file exists
# Usage: path=$(get_supabase_compose) && COMPOSE_FILES+=("-f" "$path")
get_supabase_compose() {
    local compose_file="$PROJECT_ROOT/supabase/docker/docker-compose.yml"
    if [ -f "$compose_file" ] && is_profile_active "supabase"; then
        echo "$compose_file"
        return 0
    fi
    return 1
}

# Get Dify compose file path if profile is active and file exists
# Usage: path=$(get_dify_compose) && COMPOSE_FILES+=("-f" "$path")
get_dify_compose() {
    local compose_file="$PROJECT_ROOT/dify/docker/docker-compose.yaml"
    if [ -f "$compose_file" ] && is_profile_active "dify"; then
        echo "$compose_file"
        return 0
    fi
    return 1
}

# Build array of all active compose files (main + external services)
# Appends docker-compose.override.yml last if it exists (user overrides, highest precedence)
# IMPORTANT: Requires COMPOSE_PROFILES to be set before calling (via load_env)
# Usage: build_compose_files_array; docker compose "${COMPOSE_FILES[@]}" up -d
# Result is stored in global COMPOSE_FILES array
build_compose_files_array() {
    COMPOSE_FILES=("-f" "$PROJECT_ROOT/docker-compose.yml")

    local path
    if path=$(get_n8n_workers_compose); then
        COMPOSE_FILES+=("-f" "$path")
    fi
    if path=$(get_ollama_gpu_devices_compose); then
        COMPOSE_FILES+=("-f" "$path")
    elif [ -n "${OLLAMA_GPU_DEVICES:-}" ]; then
        log_warning "OLLAMA_GPU_DEVICES is set but GPU pinning is NOT applied (requires the gpu-nvidia profile and docker-compose.ollama-gpu-devices.yml)"
    fi
    if path=$(get_invokeai_gpu_devices_compose); then
        COMPOSE_FILES+=("-f" "$path")
    elif [ -n "${INVOKEAI_GPU_DEVICES:-}" ]; then
        log_warning "INVOKEAI_GPU_DEVICES is set but GPU pinning is NOT applied (requires the invokeai-nvidia profile and docker-compose.invokeai-gpu-devices.yml)"
    fi
    if path=$(get_supabase_compose); then
        COMPOSE_FILES+=("-f" "$path")
    fi
    if path=$(get_dify_compose); then
        COMPOSE_FILES+=("-f" "$path")
    fi

    # Include user overrides last (highest precedence)
    local override="$PROJECT_ROOT/docker-compose.override.yml"
    if [ -f "$override" ]; then
        COMPOSE_FILES+=("-f" "$override")
    fi
}

#=============================================================================
# UTILITIES
#=============================================================================

# Require a command to be available
# Usage: require_command "docker" "Install Docker: https://docs.docker.com/engine/install/"
require_command() {
    local cmd="$1"
    local install_hint="${2:-Please install $cmd}"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "'$cmd' not found. $install_hint"
        exit 1
    fi
}

# Cleanup .bak files created by sed -i
# Usage: cleanup_bak_files [directory]
cleanup_bak_files() {
    local directory="${1:-$PROJECT_ROOT}"
    find "$directory" -maxdepth 1 -name "*.bak" -type f -delete 2>/dev/null || true
}

# Escape string for JSON output
# Usage: escaped=$(json_escape "string with \"quotes\"")
json_escape() {
    local str="$1"
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n\r'
}

#=============================================================================
# FILE UTILITIES
#=============================================================================

# Require a file to exist, exit with error if not found
# Usage: require_file "/path/to/file" "Custom error message"
require_file() {
    local file="$1"
    local error_msg="${2:-File not found: $file}"
    if [[ ! -f "$file" ]]; then
        log_error "$error_msg"
        exit 1
    fi
}

# Ensure a file exists, create empty file if it doesn't
# Usage: ensure_file_exists "/path/to/file"
ensure_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi
}

#=============================================================================
# COMPOSE PROFILES MANAGEMENT
#=============================================================================

# Update COMPOSE_PROFILES in .env file
# Usage: update_compose_profiles "n8n,monitoring,portainer" [env_file]
update_compose_profiles() {
    local profiles="$1"
    local env_file="${2:-$ENV_FILE}"
    ensure_file_exists "$env_file"
    if grep -q "^COMPOSE_PROFILES=" "$env_file"; then
        sed -i.bak "\|^COMPOSE_PROFILES=|d" "$env_file"
        rm -f "${env_file}.bak"
    fi
    echo "COMPOSE_PROFILES=${profiles}" >> "$env_file"
}

#=============================================================================
# DEBIAN_FRONTEND MANAGEMENT
#=============================================================================
ORIGINAL_DEBIAN_FRONTEND=""

# Save current DEBIAN_FRONTEND and set to dialog for whiptail
# Usage: save_debian_frontend
save_debian_frontend() {
    ORIGINAL_DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
    export DEBIAN_FRONTEND=dialog
}

# Restore original DEBIAN_FRONTEND value
# Usage: restore_debian_frontend
restore_debian_frontend() {
    if [[ -n "$ORIGINAL_DEBIAN_FRONTEND" ]]; then
        export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
    else
        unset DEBIAN_FRONTEND
    fi
}

#=============================================================================
# SECRET GENERATION
#=============================================================================

# Generate random string with specified characters
# Usage: gen_random 32 'A-Za-z0-9'
gen_random() {
    local length="$1"
    local characters="$2"
    head /dev/urandom | tr -dc "$characters" | head -c "$length"
}

# Generate alphanumeric password
# Usage: gen_password 32
gen_password() {
    gen_random "$1" 'A-Za-z0-9'
}

# Generate hex string
# Usage: gen_hex 64  (returns 64 hex characters)
gen_hex() {
    local length="$1"
    local bytes=$(( (length + 1) / 2 ))
    openssl rand -hex "$bytes" | head -c "$length"
}

# Generate base64 string
# Usage: gen_base64 64  (returns 64 base64 characters)
gen_base64() {
    local length="$1"
    local bytes=$(( (length * 3 + 3) / 4 ))
    openssl rand -base64 "$bytes" | head -c "$length"
}

# Generate bcrypt hash using Caddy
# Usage: hash=$(generate_bcrypt_hash "plaintext_password")
generate_bcrypt_hash() {
    local plaintext="$1"
    if [[ -n "$plaintext" ]]; then
        caddy hash-password --algorithm bcrypt --plaintext "$plaintext"
    fi
}

#=============================================================================
# VALIDATION
#=============================================================================

# Validate that a value is a positive integer
# Usage: validate_positive_integer "5" && echo "valid"
validate_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^0*[1-9][0-9]*$ ]]
}

#=============================================================================
# WHIPTAIL HELPERS
#=============================================================================

# Ensure whiptail is available
require_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        log_error "'whiptail' is not installed. Install with: sudo apt-get install -y whiptail"
        exit 1
    fi
}

# Get adaptive terminal size for whiptail dialogs
# Usage: eval "$(wt_get_size)"
# Sets: WT_HEIGHT, WT_WIDTH, WT_LIST_HEIGHT
wt_get_size() {
    local term_lines term_cols
    term_lines=$(tput lines 2>/dev/null || echo 24)
    term_cols=$(tput cols 2>/dev/null || echo 80)

    # Calculate dimensions with margins
    local height=$((term_lines - 4))
    local width=$((term_cols - 4))

    # Apply min/max constraints
    [[ $height -lt 10 ]] && height=10
    [[ $height -gt 40 ]] && height=40
    [[ $width -lt 60 ]] && width=60
    [[ $width -gt 120 ]] && width=120

    # List height for checklists/menus (leave room for title, prompt, buttons)
    local list_height=$((height - 8))
    [[ $list_height -lt 5 ]] && list_height=5

    echo "WT_HEIGHT=$height WT_WIDTH=$width WT_LIST_HEIGHT=$list_height"
}

# Input box with adaptive sizing
# Usage: result=$(wt_input "Title" "Prompt" "default")
# Returns 0 on OK, 1 on Cancel
wt_input() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    eval "$(wt_get_size)"
    local result
    result=$(whiptail --title "$title" --inputbox "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$default_value" 3>&1 1>&2 2>&3)
    local status=$?
    [[ $status -ne 0 ]] && return 1
    echo "$result"
    return 0
}

# Password box with adaptive sizing
# Usage: result=$(wt_password "Title" "Prompt")
# Returns 0 on OK, 1 on Cancel
wt_password() {
    local title="$1"
    local prompt="$2"
    eval "$(wt_get_size)"
    local result
    result=$(whiptail --title "$title" --passwordbox "$prompt" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    local status=$?
    [[ $status -ne 0 ]] && return 1
    echo "$result"
    return 0
}

# Yes/No box with adaptive sizing
# Usage: wt_yesno "Title" "Prompt" "default" (default: yes|no)
# Returns 0 for Yes, 1 for No/Cancel
wt_yesno() {
    local title="$1"
    local prompt="$2"
    local default_choice="$3"
    eval "$(wt_get_size)"
    local height=$((WT_HEIGHT < 12 ? WT_HEIGHT : 12))
    if [ "$default_choice" = "yes" ]; then
        whiptail --title "$title" --yesno "$prompt" "$height" "$WT_WIDTH"
    else
        whiptail --title "$title" --defaultno --yesno "$prompt" "$height" "$WT_WIDTH"
    fi
}

# Message box with adaptive sizing
# Usage: wt_msg "Title" "Message"
wt_msg() {
    local title="$1"
    local message="$2"
    eval "$(wt_get_size)"
    local height=$((WT_HEIGHT < 12 ? WT_HEIGHT : 12))
    whiptail --title "$title" --msgbox "$message" "$height" "$WT_WIDTH"
}

# Checklist (multiple selection) with adaptive sizing
# Usage: result=$(wt_checklist "Title" "Prompt" "tag1" "desc1" "ON" "tag2" "desc2" "OFF" ...)
# Returns: space-separated quoted tags, e.g., "tag1" "tag2"
wt_checklist() {
    local title="$1"
    local prompt="$2"
    shift 2
    eval "$(wt_get_size)"
    whiptail --title "$title" --checklist "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3
}

# Radiolist (single selection) with adaptive sizing
# Usage: result=$(wt_radiolist "Title" "Prompt" "default_item" "tag1" "desc1" "ON" ...)
# Returns: selected tag
wt_radiolist() {
    local title="$1"
    local prompt="$2"
    local default_item="$3"
    shift 3
    eval "$(wt_get_size)"
    whiptail --title "$title" --default-item "$default_item" --radiolist "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3
}

# Menu (item selection) with adaptive sizing
# Usage: result=$(wt_menu "Title" "Prompt" "tag1" "desc1" "tag2" "desc2" ...)
# Returns: selected tag
wt_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    eval "$(wt_get_size)"
    whiptail --title "$title" --menu "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3
}

# Safe parser for whiptail checklist results (replaces eval)
# Usage: wt_parse_choices "$CHOICES" result_array
# Parses quoted output like: "tag1" "tag2" "tag3"
wt_parse_choices() {
    local choices="$1"
    local -n arr="$2"
    arr=()
    # Remove quotes and split by spaces
    local cleaned="${choices//\"/}"
    read -ra arr <<< "$cleaned"
}

#=============================================================================
# LEGACY CONTAINER CLEANUP
#=============================================================================

# Remove legacy n8n worker containers from previous naming convention
# Old format: localai-n8n-worker-N (N = 1-10)
# New format: n8n-worker-N (managed by docker-compose.n8n-workers.yml)
# Usage: cleanup_legacy_n8n_workers
cleanup_legacy_n8n_workers() {
    local removed_count=0
    local container_name

    log_info "Checking for legacy n8n worker containers..."

    for i in {1..10}; do
        container_name="localai-n8n-worker-$i"

        # Check if container exists (running or stopped)
        if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            log_info "Removing legacy container: $container_name"
            docker stop "$container_name" 2>/dev/null || true
            docker rm -f "$container_name" 2>/dev/null || true
            removed_count=$((removed_count + 1))
        fi
    done

    if [ $removed_count -gt 0 ]; then
        log_success "Removed $removed_count legacy n8n worker container(s)"
    else
        log_info "No legacy n8n worker containers found"
    fi
}

# Clean up legacy postgresus container after rename to databasus
# This function removes the old "postgresus" container if it exists,
# allowing the new "databasus" container to take its place.
# Usage: cleanup_legacy_postgresus
cleanup_legacy_postgresus() {
    local container_name="postgresus"

    # Check if container exists (running or stopped)
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Found legacy postgresus container, migrating to databasus..."
        docker stop "$container_name" 2>/dev/null || true
        docker rm -f "$container_name" 2>/dev/null || true
        log_success "Legacy postgresus container removed. Databasus will use existing data via volume alias."
    fi
}

#=============================================================================
# USER DETECTION
#=============================================================================

# Get the real user who invoked the script (even when running with sudo)
# Usage: real_user=$(get_real_user)
# Returns: username of the real user, or "root" if cannot determine
get_real_user() {
    # Try SUDO_USER first (set by sudo)
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
        return 0
    fi

    # Try logname (gets login name)
    local logname_user
    logname_user=$(logname 2>/dev/null) || true
    if [[ -n "$logname_user" && "$logname_user" != "root" ]]; then
        echo "$logname_user"
        return 0
    fi

    # Try who am i (gets TTY user)
    local who_user
    who_user=$(who am i 2>/dev/null | awk '{print $1}') || true
    if [[ -n "$who_user" && "$who_user" != "root" ]]; then
        echo "$who_user"
        return 0
    fi

    # Check if we're in a user's home directory
    local current_dir="$PWD"
    if [[ "$current_dir" =~ ^/home/([^/]+) ]]; then
        local home_user="${BASH_REMATCH[1]}"
        if id "$home_user" &>/dev/null; then
            echo "$home_user"
            return 0
        fi
    fi

    # Fallback to current user
    whoami
}

# Get the home directory of the real user
# Usage: real_home=$(get_real_user_home)
get_real_user_home() {
    local real_user
    real_user=$(get_real_user)
    eval echo "~$real_user"
}

#=============================================================================
# DIRECTORY PRESERVATION (for git updates)
#=============================================================================
# Directories containing user-customizable content that should survive git reset.
# Used by update.sh to backup before git operations and restore after.
PRESERVE_DIRS=("python-runner")

# Backup preserved directories before git reset
# Usage: backup_path=$(backup_preserved_dirs) || exit 1
# Returns: 0 on success (prints backup path to stdout), 1 on failure
# NOTE: All logs go to stderr to keep stdout clean for the return value
backup_preserved_dirs() {
    local backup_base=""
    local has_content=0

    # Check if any directories need backup
    for dir in "${PRESERVE_DIRS[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ] && [ -n "$(ls -A "$PROJECT_ROOT/$dir" 2>/dev/null)" ]; then
            has_content=1
            break
        fi
    done

    # No content to backup
    if [ $has_content -eq 0 ]; then
        echo ""
        return 0
    fi

    # Create secure temporary directory
    backup_base=$(mktemp -d /tmp/selfhost-ai-backup.XXXXXXXXXX) || {
        echo "[ERROR] Failed to create backup directory" >&2
        return 1
    }
    chmod 700 "$backup_base"

    # Backup each directory
    for dir in "${PRESERVE_DIRS[@]}"; do
        # Validate directory name (no path traversal)
        if [[ "$dir" =~ \.\.|^/ ]]; then
            echo "[ERROR] Invalid directory name in PRESERVE_DIRS: $dir" >&2
            rm -rf "$backup_base"
            return 1
        fi

        if [ -d "$PROJECT_ROOT/$dir" ] && [ -n "$(ls -A "$PROJECT_ROOT/$dir" 2>/dev/null)" ]; then
            echo "[INFO] Backing up $dir/ before git reset..." >&2
            if ! cp -rp "$PROJECT_ROOT/$dir" "$backup_base/$dir"; then
                echo "[ERROR] Failed to backup $dir/. Aborting to prevent data loss." >&2
                rm -rf "$backup_base"
                return 1
            fi
        fi
    done

    echo "$backup_base"
    return 0
}

# Restore preserved directories after git reset
# Usage: restore_preserved_dirs <backup_base_path>
# Returns: 0 on success, 1 on failure
restore_preserved_dirs() {
    local backup_base="$1"

    # Nothing to restore
    if [ -z "$backup_base" ]; then
        return 0
    fi

    if [ ! -d "$backup_base" ]; then
        log_warning "Backup directory not found: $backup_base"
        return 0
    fi

    # Safety checks for PROJECT_ROOT
    if [ -z "$PROJECT_ROOT" ]; then
        log_error "PROJECT_ROOT is not set. Refusing to restore."
        return 1
    fi

    if [ "$PROJECT_ROOT" = "/" ] || [ "$PROJECT_ROOT" = "/root" ] || [ "$PROJECT_ROOT" = "/home" ]; then
        log_error "PROJECT_ROOT is set to a dangerous path: $PROJECT_ROOT"
        return 1
    fi

    for dir in "${PRESERVE_DIRS[@]}"; do
        # Validate directory name
        if [[ "$dir" =~ \.\.|^/ ]] || [ -z "$dir" ]; then
            log_error "Invalid directory name: $dir"
            continue
        fi

        if [ -d "$backup_base/$dir" ]; then
            log_info "Restoring $dir/ after git reset..."

            # Remove the git-restored version
            if [ -d "$PROJECT_ROOT/$dir" ]; then
                if ! rm -rf "$PROJECT_ROOT/$dir"; then
                    log_error "Failed to remove $PROJECT_ROOT/$dir"
                    return 1
                fi
            fi

            # Restore from backup
            if ! mv "$backup_base/$dir" "$PROJECT_ROOT/$dir"; then
                log_error "Failed to restore $dir/ from backup"
                return 1
            fi
        fi
    done

    # Cleanup backup directory
    rm -rf "$backup_base"
    return 0
}
