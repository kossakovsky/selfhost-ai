#!/bin/bash
# =============================================================================
# apply_update.sh - Service update and restart logic
# =============================================================================
# Called by update.sh after git sync. Performs the actual service updates:
#   1. Updates .env with any new variables (03_generate_secrets.sh --update)
#   2. Runs service selection wizard (04_wizard.sh) to update profiles
#   3. Configures services (05_configure_services.sh)
#   4. Pulls latest Docker images for selected services
#   5. Restarts all services (06_run_services.sh)
#   6. Displays final report (07_final_report.sh)
#
# Handles multiple compose files: main, n8n-workers, Supabase, and Dify.
#
# Usage: Called automatically by update.sh (not typically run directly)
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Source git utilities
source "$SCRIPT_DIR/git.sh"

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# Setup error telemetry trap for tracking failures
setup_error_telemetry_trap

# Set the compose command explicitly to use docker compose subcommand
COMPOSE_CMD="docker compose"

# Path to the 06_run_services.sh script
RUN_SERVICES_SCRIPT="$SCRIPT_DIR/06_run_services.sh"

# Check if run services script exists
require_file "$RUN_SERVICES_SCRIPT" "$RUN_SERVICES_SCRIPT not found."

cd "$PROJECT_ROOT"

# Repoint remotes still targeting the pre-rename repository URL. Also
# called here (not only in update.sh) so installations updating FROM an
# old version get healed in the same run: the old update.sh has already
# fetched the new code via GitHub's redirect by the time this executes.
git_heal_renamed_remotes

# Send telemetry: update started
send_telemetry "update_start"

# --- Call 03_generate_secrets.sh in update mode ---
set_telemetry_stage "update_env"
log_info "Ensuring .env file is up-to-date with all variables..."
bash "$SCRIPT_DIR/03_generate_secrets.sh" --update || {
    log_error "Failed to update .env configuration via 03_generate_secrets.sh. Update process cannot continue."
    exit 1
}
log_success ".env file updated successfully."
# --- End of .env update by 03_generate_secrets.sh ---

# --- Run Service Selection Wizard FIRST to get updated profiles ---
set_telemetry_stage "update_wizard"
log_info "Running Service Selection Wizard to update service choices..."
bash "$SCRIPT_DIR/04_wizard.sh" || {
    log_error "Service Selection Wizard failed. Update process cannot continue."
    exit 1
}
log_success "Service selection updated."
# --- End of Service Selection Wizard ---

# --- Configure Services (prompts and .env updates) ---
set_telemetry_stage "update_configure"
log_info "Configuring services (.env updates for optional inputs)..."
bash "$SCRIPT_DIR/05_configure_services.sh" || {
    log_error "Configure Services failed. Update process cannot continue."
    exit 1
}
log_success "Service configuration completed."

# Clean up legacy containers from old naming conventions
cleanup_legacy_n8n_workers
cleanup_legacy_postgresus

# Pull latest versions of selected containers based on updated .env
set_telemetry_stage "update_docker_pull"
log_info "Pulling latest versions of selected containers..."

# Load environment to check active profiles (wizard may have updated them)
load_env

# Build compose files array using shared function (checks profile + file existence)
build_compose_files_array

# Use the project name "localai" for consistency.
# This command WILL respect COMPOSE_PROFILES from the .env file (updated by the wizard above).
$COMPOSE_CMD -p "localai" "${COMPOSE_FILES[@]}" pull --ignore-buildable || {
  log_error "Failed to pull Docker images for selected services. Check network connection and Docker Hub status."
  exit 1
}

# Start PostgreSQL first to initialize databases before other services
set_telemetry_stage "update_db_init"
log_info "Starting PostgreSQL..."
$COMPOSE_CMD -p "localai" up -d postgres || { log_error "Failed to start PostgreSQL"; exit 1; }

# Initialize PostgreSQL databases for services (creates if not exist)
# This must run BEFORE other services that depend on these databases
source "$SCRIPT_DIR/databases.sh"
init_all_databases || { log_warning "Database initialization had issues, but continuing..."; }

# Start all services using the 06_run_services.sh script (postgres is already running)
set_telemetry_stage "update_services_start"
log_info "Running Services..."
bash "$RUN_SERVICES_SCRIPT" || { log_error "Failed to start services. Check logs for details."; exit 1; }

log_success "Update application completed successfully!"

# --- Fix file permissions ---
set_telemetry_stage "update_fix_perms"
log_info "Fixing file permissions..."
bash "$SCRIPT_DIR/08_fix_permissions.sh" || {
    log_warning "Failed to fix file permissions. This does not affect the update."
}
# --- End of Fix permissions ---

# --- Display Final Report with Credentials ---
set_telemetry_stage "update_final_report"
bash "$SCRIPT_DIR/07_final_report.sh" || {
    log_warning "Failed to display the final report. This does not affect the update."
    # We don't exit 1 here as the update itself was successful.
}
# --- End of Final Report ---

# Send telemetry: update completed with current services
send_telemetry "update_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
