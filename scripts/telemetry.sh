#!/bin/bash
# =============================================================================
# telemetry.sh - Anonymous telemetry for Selfhost AI
# =============================================================================
# Sends anonymous usage statistics to help improve the project.
# No personal data is collected. Users can opt-out by setting:
#   SCARF_ANALYTICS=false or DO_NOT_TRACK=1
#
# Depends on: utils.sh (must be sourced first for ENV_FILE, PROJECT_ROOT)
#
# Functions:
#   get_installation_id()        - Get or generate persistent installation ID
#   get_os_type()                - Detect OS type
#   send_telemetry()             - Send anonymous telemetry event
#   set_telemetry_stage()        - Set current stage for error tracking
#   send_error_telemetry()       - Send error telemetry event
#   setup_error_telemetry_trap() - Setup global ERR trap
#   save_installation_id()       - Save installation ID to .env
#
# Usage: source "$SCRIPT_DIR/telemetry.sh"
# =============================================================================

# Scarf endpoint for anonymous telemetry
# The /n8n-install path is the project's original name; the Scarf endpoint
# was registered before the selfhost-ai rename and must stay unchanged
SCARF_ENDPOINT="https://kossakovsky.gateway.scarf.sh/n8n-install"

#=============================================================================
# INSTALLATION ID
#=============================================================================

# Get or generate installation ID (persistent across sessions)
# Usage: id=$(get_installation_id)
# Priority: 1) exported env var, 2) .env file, 3) generate new
get_installation_id() {
    # First check if ID is already in environment (exported from parent process)
    # This ensures consistency when called multiple times before .env exists
    if [[ -n "${INSTALLATION_ID:-}" ]]; then
        echo "$INSTALLATION_ID"
        return 0
    fi

    # Then check .env file for existing ID
    if [[ -f "$ENV_FILE" ]]; then
        local existing_id
        existing_id=$(grep "^INSTALLATION_ID=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [[ -n "$existing_id" ]]; then
            echo "$existing_id"
            return 0
        fi
    fi

    # Generate new ID (12 char hex = 6 bytes)
    local new_id
    new_id=$(od -An -tx1 -N6 /dev/urandom | tr -d ' \n')

    # Save to .env if file exists
    if [[ -f "$ENV_FILE" ]]; then
        if grep -q "^INSTALLATION_ID=" "$ENV_FILE" 2>/dev/null; then
            sed -i.bak "s/^INSTALLATION_ID=.*/INSTALLATION_ID=\"${new_id}\"/" "$ENV_FILE"
            rm -f "${ENV_FILE}.bak"
        else
            echo "INSTALLATION_ID=\"${new_id}\"" >> "$ENV_FILE"
        fi
    fi

    echo "$new_id"
}

# Save installation ID to .env file
# Usage: save_installation_id
# Priority: 1) exported from parent, 2) existing .env, 3) generate new
# Note: Requires write_env_var from utils.sh
save_installation_id() {
    local output_file="${1:-$ENV_FILE}"

    # Priority: exported var > existing .env value > generate new
    local install_id="${INSTALLATION_ID:-}"

    if [[ -z "$install_id" && -f "$output_file" ]]; then
        install_id=$(grep "^INSTALLATION_ID=" "$output_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    fi

    if [[ -z "$install_id" ]]; then
        # Generate new ID for existing installations upgrading from pre-telemetry version
        install_id=$(od -An -tx1 -N6 /dev/urandom | tr -d ' \n')
    fi

    write_env_var "INSTALLATION_ID" "$install_id" "$output_file"
}

#=============================================================================
# OS DETECTION
#=============================================================================

# Detect OS type
# Usage: os=$(get_os_type)
get_os_type() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-linux}-${VERSION_ID:-unknown}"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos-$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    else
        echo "$(uname -s | tr '[:upper:]' '[:lower:]')-unknown"
    fi
}

#=============================================================================
# TELEMETRY EVENTS
#=============================================================================

# Send anonymous telemetry event
# Usage: send_telemetry "install_start"
#        send_telemetry "install_complete" "$COMPOSE_PROFILES"
#        send_telemetry "update_start"
#        send_telemetry "update_complete" "$COMPOSE_PROFILES"
# Arguments:
#   $1 - event_type: "install_start", "install_complete", "update_start", "update_complete"
#   $2 - services (optional): comma-separated list of selected profiles (for *_complete events)
#        When provided, sends a separate request for each service to enable per-service analytics.
# Note: To get installation ID, call get_installation_id directly before this function
send_telemetry() {
    local event_type="$1"
    local services="${2:-}"

    # Load environment (for SCARF_ANALYTICS check and INSTALLATION_ID)
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" 2>/dev/null

    # Get installation ID and OS
    local install_id
    install_id=$(get_installation_id)
    local os_type
    os_type=$(get_os_type)

    # Opt-out check: respect SCARF_ANALYTICS and DO_NOT_TRACK
    if [[ "${SCARF_ANALYTICS:-true}" == "false" ]] || [[ "${DO_NOT_TRACK:-0}" == "1" ]]; then
        return 0
    fi

    # Get version from VERSION file
    local version="unknown"
    if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
        version=$(cat "$PROJECT_ROOT/VERSION" | tr -d '\n\r')
    fi

    # Build base URL with query parameters
    local base_url="${SCARF_ENDPOINT}?event=${event_type}&version=${version}&id=${install_id}&os=${os_type}"

    if [[ -n "$services" ]]; then
        # Split services by comma and send individual request for each service
        # This allows Scarf to track usage statistics per service
        local service
        IFS=',' read -ra service_array <<< "$services"
        for service in "${service_array[@]}"; do
            # Trim whitespace
            service=$(echo "$service" | xargs)
            [[ -z "$service" ]] && continue
            # Send telemetry for this service in background
            curl -sf --connect-timeout 2 --max-time 2 "${base_url}&services=${service}" >/dev/null 2>&1 &
        done
    else
        # No services specified, send single event
        curl -sf --connect-timeout 2 --max-time 2 "$base_url" >/dev/null 2>&1 &
    fi
}

#=============================================================================
# ERROR TELEMETRY
#=============================================================================
# Tracks installation/update failures with stage and exit code.
# Uses same opt-out as regular telemetry (SCARF_ANALYTICS=false or DO_NOT_TRACK=1)

# Set current telemetry stage for error tracking
# Usage: set_telemetry_stage "system_prep"
set_telemetry_stage() {
    export TELEMETRY_STAGE="$1"
}

# Send error telemetry event (called by trap handler)
# Usage: send_error_telemetry 1
# Arguments:
#   $1 - exit_code: The exit code that triggered the error
send_error_telemetry() {
    local exit_code="${1:-1}"
    local stage="${TELEMETRY_STAGE:-unknown}"

    # Prevent duplicate sends
    [[ "${TELEMETRY_ERROR_SENT:-0}" == "1" ]] && return 0
    export TELEMETRY_ERROR_SENT=1

    # Load environment (for SCARF_ANALYTICS check)
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" 2>/dev/null

    # Opt-out check: respect SCARF_ANALYTICS and DO_NOT_TRACK
    [[ "${SCARF_ANALYTICS:-true}" == "false" || "${DO_NOT_TRACK:-0}" == "1" ]] && return 0

    # Determine event type based on stage prefix
    local event_type="install_error"
    [[ "$stage" == update_* || "$stage" == git_* ]] && event_type="update_error"

    # Get installation ID and OS
    local install_id
    install_id=$(get_installation_id)
    local os_type
    os_type=$(get_os_type)

    # Get version from VERSION file
    local version="unknown"
    [[ -f "$PROJECT_ROOT/VERSION" ]] && version=$(cat "$PROJECT_ROOT/VERSION" | tr -d '\n\r')

    # Build URL with error-specific parameters
    local url="${SCARF_ENDPOINT}?event=${event_type}&version=${version}&id=${install_id}&os=${os_type}&stage=${stage}&exit_code=${exit_code}"

    # Send telemetry in background with short timeout (non-blocking, silent)
    curl -sf --connect-timeout 2 --max-time 2 "$url" >/dev/null 2>&1 &
}

# Internal trap handler for ERR signal
_telemetry_error_handler() {
    local exit_code=$?
    # Only send if we actually have an error (exit_code > 0)
    [[ $exit_code -gt 0 ]] && send_error_telemetry "$exit_code"
    # Re-exit with the original code (important for set -e behavior)
    exit $exit_code
}

# Setup global ERR trap for error telemetry
# Usage: setup_error_telemetry_trap
# Note: Only call this in top-level orchestrator scripts (install.sh, apply_update.sh, update.sh)
setup_error_telemetry_trap() {
    trap '_telemetry_error_handler' ERR
}
