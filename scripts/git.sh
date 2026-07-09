#!/bin/bash
# =============================================================================
# git.sh - Git utilities for Selfhost AI scripts
# =============================================================================
# Provides git-related functions for repository management.
#
# Functions:
#   - require_git: Verify git is installed
#   - git_get_current_branch: Get current branch name (main/develop)
#   - git_sync_with_origin: Fetch and reset to origin/<branch>
#   - git_configure_pull_rebase: Configure git to use rebase on pull
#
# Usage: source "$(dirname "$0")/git.sh"
# Note: Requires utils.sh to be sourced first for logging functions.
# =============================================================================

# Supported branches for this project
GIT_SUPPORTED_BRANCHES=("main" "develop")
GIT_DEFAULT_BRANCH="main"

#=============================================================================
# GIT CHECKS
#=============================================================================

# Check if git is installed
# Usage: require_git || exit 1
require_git() {
    if ! command -v git &> /dev/null; then
        log_error "'git' command not found. Please install git."
        return 1
    fi
    return 0
}

#=============================================================================
# BRANCH MANAGEMENT
#=============================================================================

# Get current git branch name
# Returns default branch if on detached HEAD or unknown branch
# Usage: branch=$(git_get_current_branch)
git_get_current_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    # If empty (detached HEAD), use default
    if [[ -z "$branch" ]]; then
        echo "$GIT_DEFAULT_BRANCH"
        return 0
    fi

    # Check if branch is in supported list
    local is_supported=0
    for supported in "${GIT_SUPPORTED_BRANCHES[@]}"; do
        if [[ "$branch" == "$supported" ]]; then
            is_supported=1
            break
        fi
    done

    if [[ $is_supported -eq 0 ]]; then
        log_warning "Unknown branch '$branch', using $GIT_DEFAULT_BRANCH"
        echo "$GIT_DEFAULT_BRANCH"
        return 0
    fi

    echo "$branch"
}

#=============================================================================
# SYNC OPERATIONS
#=============================================================================

# Sync local repository with origin using hard reset
# Fetches latest changes and resets to origin/<branch>
# This discards any local commits to ensure clean sync with remote
# Usage: git_sync_with_origin [target_branch]
# Returns: 0 on success, 1 on failure
git_sync_with_origin() {
    local target_branch="${1:-}"

    # Determine target branch if not specified
    if [[ -z "$target_branch" ]]; then
        target_branch=$(git_get_current_branch)
    fi

    # Fetch latest changes from origin
    log_info "Fetching latest changes from origin..."
    if ! git fetch origin; then
        log_error "Git fetch failed. Check your internet connection."
        return 1
    fi

    # Reset to origin/<branch>
    log_info "Resetting to origin/$target_branch..."
    if ! git reset --hard "origin/$target_branch"; then
        log_error "Git reset to origin/$target_branch failed."
        return 1
    fi

    log_info "Successfully synced with origin/$target_branch"
    return 0
}

# Merge changes from upstream remote (for forks)
# Fetches from upstream and merges main branch into current branch
# Preserves local commits - suitable for fork workflows
# Usage: git_merge_from_upstream
# Returns: 0 on success, 1 on failure
git_merge_from_upstream() {
    local upstream_branch="main"

    # Check if upstream remote exists
    if ! git remote get-url upstream &>/dev/null; then
        log_error "Remote 'upstream' not configured."
        log_info "Add it with: git remote add upstream <original-repo-url>"
        return 1
    fi

    # Fetch latest changes from upstream
    log_info "Fetching latest changes from upstream..."
    if ! git fetch upstream; then
        log_error "Git fetch from upstream failed. Check your internet connection."
        return 1
    fi

    # Merge upstream changes into current branch
    log_info "Merging upstream/$upstream_branch into current branch..."
    if ! git merge "upstream/$upstream_branch" --no-edit; then
        log_error "Git merge from upstream/$upstream_branch failed."
        log_error "You may need to resolve conflicts manually."
        return 1
    fi

    log_success "Successfully merged changes from upstream/$upstream_branch"
    return 0
}

#=============================================================================
# CONFIGURATION
#=============================================================================

# Configure git to use rebase on pull (prevents merge commits)
# Usage: git_configure_pull_rebase
git_configure_pull_rebase() {
    if [[ -z "$(git config --global pull.rebase 2>/dev/null)" ]]; then
        log_info "Configuring git pull strategy (rebase)..."
        git config --global pull.rebase true
    fi
}
