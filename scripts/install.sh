#!/bin/bash
# =============================================================================
# install.sh - Main installation orchestrator for Selfhost AI
# =============================================================================
# This script runs the complete installation process by sequentially executing
# 8 installation steps:
#   1. System Preparation - updates packages, installs utilities, configures firewall
#   2. Docker Installation - installs Docker and Docker Compose
#   3. Secret Generation - creates .env file with secure passwords and secrets
#   4. Service Wizard - interactive service selection using whiptail
#   5. Service Configuration - prompts for API keys and service-specific settings
#   6. Service Launch - starts all selected services via Docker Compose
#   7. Final Report - displays credentials and access URLs
#   8. Fix Permissions - ensures correct file ownership for the invoking user
#
# Usage: sudo bash scripts/install.sh
# =============================================================================

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Check for nested project directory (the repo can be cloned as
# selfhost-ai or, via the pre-rename URLs, n8n-install / n8n-installer)
current_path=$(pwd)
for _repo_dir in "selfhost-ai" "n8n-install" "n8n-installer"; do
    if [[ "$current_path" == *"/${_repo_dir}/${_repo_dir}" ]]; then
        # Only treat this as an accidental nested clone if the parent
        # directory is itself a copy of this repository. A same-named plain
        # folder holding a fresh clone (e.g. ~/selfhost-ai/selfhost-ai) is a
        # normal layout: install from the current clone, delete nothing.
        if [[ -f "../scripts/install.sh" && -f "../docker-compose.yml" ]]; then
            log_info "Detected nested ${_repo_dir} clone inside another copy of the repository. Correcting..."
            cd ..
            log_info "Removing redundant nested ${_repo_dir} directory..."
            rm -rf "${_repo_dir}"
            # The deleted clone may be where this script was loaded from, so
            # relative paths can no longer be trusted: restart the installer
            # from the surviving outer copy.
            log_info "Re-executing installer from $(pwd)..."
            exec sudo bash "./scripts/install.sh" "$@"
        fi
        break
    fi
done

# Initialize paths using utils.sh helper
init_paths

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# Setup error telemetry trap for tracking failures
setup_error_telemetry_trap

# Generate installation ID for telemetry correlation (before .env exists)
# This ID will be saved to .env by 03_generate_secrets.sh
INSTALLATION_ID=$(get_installation_id)
export INSTALLATION_ID

# Send telemetry: installation started
send_telemetry "install_start"

# Check if all required scripts exist and are executable in the current directory
required_scripts=(
    "01_system_preparation.sh"
    "02_install_docker.sh"
    "03_generate_secrets.sh"
    "04_wizard.sh"
    "05_configure_services.sh"
    "06_run_services.sh"
    "07_final_report.sh"
    "08_fix_permissions.sh"
)

missing_scripts=()
non_executable_scripts=()

for script in "${required_scripts[@]}"; do
    # Check directly in the current directory (SCRIPT_DIR)
    script_path="$SCRIPT_DIR/$script"
    if [ ! -f "$script_path" ]; then
        missing_scripts+=("$script")
    elif [ ! -x "$script_path" ]; then
        non_executable_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    # Update error message to reflect current directory check
    log_error "The following required scripts are missing in $SCRIPT_DIR:"
    printf " - %s\n" "${missing_scripts[@]}"
    exit 1
fi

# Attempt to make scripts executable if they are not
if [ ${#non_executable_scripts[@]} -gt 0 ]; then
    log_warning "The following scripts were not executable and will be made executable:"
    printf " - %s\n" "${non_executable_scripts[@]}"
    # Make all .sh files in the current directory executable
    chmod +x "$SCRIPT_DIR"/*.sh
    # Re-check after chmod
    for script in "${non_executable_scripts[@]}"; do
         script_path="$SCRIPT_DIR/$script"
         if [ ! -x "$script_path" ]; then
            # Update error message
            log_error "Failed to make '$script' in $SCRIPT_DIR executable. Please check permissions."
            exit 1
         fi
    done
    log_success "Scripts successfully made executable."
fi

# Run installation steps sequentially using their full paths

show_step 1 8 "System Preparation"
set_telemetry_stage "system_prep"
bash "$SCRIPT_DIR/01_system_preparation.sh" || { log_error "System Preparation failed"; exit 1; }
log_success "System preparation complete!"

show_step 2 8 "Installing Docker"
set_telemetry_stage "docker_install"
bash "$SCRIPT_DIR/02_install_docker.sh" || { log_error "Docker Installation failed"; exit 1; }
log_success "Docker installation complete!"

show_step 3 8 "Generating Secrets and Configuration"
set_telemetry_stage "secrets_gen"
bash "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

show_step 4 8 "Running Service Selection Wizard"
set_telemetry_stage "wizard"
bash "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

show_step 5 8 "Configure Services"
set_telemetry_stage "configure"
bash "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

show_step 6 8 "Running Services"
set_telemetry_stage "db_init"
# Start PostgreSQL first to initialize databases before other services
log_info "Starting PostgreSQL..."
docker compose -p localai up -d postgres || { log_error "Failed to start PostgreSQL"; exit 1; }

# Initialize PostgreSQL databases for services (creates if not exist)
# This must run BEFORE other services that depend on these databases
source "$SCRIPT_DIR/databases.sh"
init_all_databases || { log_warning "Database initialization had issues, but continuing..."; }

# Now start all services (postgres is already running)
set_telemetry_stage "services_start"
bash "$SCRIPT_DIR/06_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

show_step 7 8 "Generating Final Report"
set_telemetry_stage "final_report"
# --- Installation Summary ---
log_info "Installation Summary:"
echo -e "  ${GREEN}*${NC} System updated and basic utilities installed"
echo -e "  ${GREEN}*${NC} Firewall (UFW) configured and enabled"
echo -e "  ${GREEN}*${NC} Fail2Ban activated for brute-force protection"
echo -e "  ${GREEN}*${NC} Automatic security updates enabled"
echo -e "  ${GREEN}*${NC} Docker and Docker Compose installed"
echo -e "  ${GREEN}*${NC} '.env' generated with secure passwords and secrets"
echo -e "  ${GREEN}*${NC} Services launched via Docker Compose"

bash "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report generated!"

show_step 8 8 "Fixing File Permissions"
set_telemetry_stage "fix_perms"
bash "$SCRIPT_DIR/08_fix_permissions.sh" || { log_error "Fix Permissions failed"; exit 1; }
log_success "File permissions fixed!"

log_success "Installation complete!"

# Send telemetry: installation completed with selected services
send_telemetry "install_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
