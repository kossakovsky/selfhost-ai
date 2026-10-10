#!/bin/bash
# =============================================================================
# 01_system_preparation.sh - System preparation and security hardening
# =============================================================================
# Prepares an Ubuntu/Debian system for running Docker services:
#   - Updates system packages and installs essential CLI tools
#   - Configures UFW firewall (allows SSH, HTTP, HTTPS; denies other incoming)
#   - Enables Fail2Ban for SSH brute-force protection
#   - Sets up automatic security updates via unattended-upgrades
#   - Configures vm.max_map_count for Elasticsearch (required by RAGFlow)
#
# Required: Must be run as root (sudo)
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Source git utilities
source "$SCRIPT_DIR/git.sh"

export DEBIAN_FRONTEND=noninteractive

# System Update
log_subheader "System Update"
log_info "Updating package list..."
remove_legacy_caddy_apt_source
apt update -y
log_info "Enabling universe repository..."
apt install -y software-properties-common
add-apt-repository universe -y
log_info "Upgrading the system..."
apt upgrade -y

# Installing Basic Utilities
log_subheader "Installing Utilities"
log_info "Installing standard CLI tools..."
apt install -y \
  git curl make ufw fail2ban python3 psmisc whiptail \
  build-essential ca-certificates gnupg lsb-release openssl \
  apt-transport-https python3-dotenv python3-yaml

# Configure git to use rebase on pull (prevents merge commits during updates)
git_configure_pull_rebase

# Configuring Firewall (UFW)
log_subheader "Firewall (UFW)"
log_info "Configuring firewall..."
echo "y" | ufw reset
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw reload
ufw status

# Configuring Fail2Ban
log_subheader "Fail2Ban"
log_info "Enabling brute-force protection..."
systemctl enable fail2ban
sleep 1
systemctl start fail2ban
sleep 1
fail2ban-client status
sleep 1
fail2ban-client status sshd

# Automatic Security Updates
log_subheader "Security Updates"
log_info "Enabling automatic security updates..."
apt install -y unattended-upgrades
# Automatic confirmation for dpkg-reconfigure
echo "y" | dpkg-reconfigure --priority=low unattended-upgrades

# Configure vm.max_map_count for Elasticsearch (required for RAGFlow)
log_subheader "Kernel Parameters"
log_info "Configuring vm.max_map_count for Elasticsearch..."
CURRENT_VALUE=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
if [[ "$CURRENT_VALUE" -lt 262144 ]]; then
  log_info "Setting vm.max_map_count=262144 (current: $CURRENT_VALUE)..."
  sysctl -w vm.max_map_count=262144

  # Make it permanent
  if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    log_info "Added vm.max_map_count to /etc/sysctl.conf for persistence"
  fi
else
  log_info "vm.max_map_count already configured (current: $CURRENT_VALUE)"
fi

exit 0 