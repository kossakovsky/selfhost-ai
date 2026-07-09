#!/bin/bash
# =============================================================================
# update.sh - Main update orchestrator
# =============================================================================
# Performs a full system and service update:
#   1. Backs up user-customizable directories (e.g., python-runner/)
#   2. Syncs with remote repository (method depends on GIT_MODE)
#   3. Restores backed up directories to preserve user modifications
#   4. Updates Ubuntu system packages (apt-get update && upgrade)
#   5. Delegates to apply_update.sh for service updates
#
# This two-stage approach ensures apply_update.sh itself gets updated before
# running, so new update logic is always applied.
#
# Git modes (set via GIT_MODE environment variable):
#   - reset (default): git fetch + reset --hard origin/<branch>
#     Best for: Standard installations, always syncs cleanly with remote
#   - merge: git fetch upstream + merge upstream/<branch>
#     Best for: Forks that maintain their own changes and merge from upstream
#
# Preserved directories: Defined in PRESERVE_DIRS array in utils.sh.
# These directories contain user-customizable content that survives git reset.
#
# Usage:
#   make update      - Standard update (reset mode)
#   make git-pull    - Fork update (merge mode)
#   GIT_MODE=merge sudo bash scripts/update.sh  - Manual merge mode
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

# Global variable to track backup path for cleanup
BACKUP_PATH=""

# Cleanup function for interrupted updates
cleanup_on_exit() {
    local exit_code=$?
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ]; then
        log_warning "Cleaning up backup directory: $BACKUP_PATH"
        rm -rf "$BACKUP_PATH"
    fi
    exit $exit_code
}
trap cleanup_on_exit INT TERM

# Path to the apply_update.sh script
APPLY_UPDATE_SCRIPT="$SCRIPT_DIR/apply_update.sh"

# Check if apply update script exists
if [ ! -f "$APPLY_UPDATE_SCRIPT" ]; then
    log_error "Crucial update script $APPLY_UPDATE_SCRIPT not found. Cannot proceed."
    exit 1
fi


log_info "Starting update process..."
set_telemetry_stage "git_update"

# Sync with the latest repository changes
log_info "Syncing with latest repository changes..."

# Check if git is installed
if ! require_git; then
    exit 1
fi

# Change to project root for git operations
cd "$PROJECT_ROOT" || { log_error "Failed to change directory to $PROJECT_ROOT"; exit 1; }

# Repoint remotes still targeting the pre-rename repository URL
git_heal_renamed_remotes

# Backup user-customizable directories before git reset (uses PRESERVE_DIRS from utils.sh)
if ! BACKUP_PATH=$(backup_preserved_dirs); then
    log_error "Backup failed. Aborting update to prevent data loss."
    exit 1
fi

if [ -n "$BACKUP_PATH" ]; then
    log_info "Backup created at: $BACKUP_PATH"
fi

# Sync with remote repository based on GIT_MODE
if [[ "${GIT_MODE:-reset}" == "merge" ]]; then
    # Fork workflow: merge from upstream (preserves local commits)
    log_info "Using merge mode (for forks)..."
    if ! git_merge_from_upstream; then
        restore_preserved_dirs "$BACKUP_PATH"
        exit 1
    fi
else
    # Standard workflow: reset to origin (discards local commits)
    if ! git_sync_with_origin; then
        restore_preserved_dirs "$BACKUP_PATH"
        exit 1
    fi
fi

# Restore user-customizable directories after git reset
if ! restore_preserved_dirs "$BACKUP_PATH"; then
    log_error "Failed to restore user directories from backup."
    log_error "Backup may still be available at: $BACKUP_PATH"
    BACKUP_PATH=""  # Prevent cleanup from deleting it
    exit 1
fi

# Clear backup path after successful restore
BACKUP_PATH=""

# Update Ubuntu packages before running apply_update
set_telemetry_stage "git_system_packages"
log_info "Updating system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get upgrade -y
    log_info "System packages updated successfully."
else
    log_warning "'apt-get' not found. Skipping system package update. This is normal on non-debian systems."
fi


# Execute the rest of the update process using the (potentially updated) apply_update.sh
# Note: apply_update.sh has its own error telemetry trap and stages
bash "$APPLY_UPDATE_SCRIPT"

exit 0