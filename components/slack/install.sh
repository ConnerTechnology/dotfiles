#!/usr/bin/env bash

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Slack"

OS=$(detect_os)
ARCH=$(detect_arch)
PM=$(get_package_manager)

# WSL: Install Slack on Windows side via winget
if is_wsl; then
  if [[ "${FORCE:-false}" != "true" ]] && is_winget_installed "SlackTechnologies.Slack"; then
    log_info "Slack is already installed on Windows"
    exit 0
  fi
  install_winget "SlackTechnologies.Slack" "Slack"
  log_success "Slack installed on Windows via winget"
  create_install_marker slack
  exit 0
fi

if [[ "$OS" == "macos" ]]; then
  check_installed_app "Slack" && exit 0
else
  check_installed_cmd "slack" "slack --version" && exit 0
fi

log_info "Slack is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
  install_brew_cask slack
  log_success "Slack installed successfully"
elif [[ "$PM" == "apt" ]]; then
  # Debian/Ubuntu: Download and install .deb package
  if [[ "$ARCH" != "amd64" ]]; then
    log_warning "Slack installation not supported on $ARCH architecture"
    log_info "Install Slack via snap or use https://slack.com"
    exit 2
  fi
  ensure_wget_installed

  TEMP_DIR=$(mktemp -d)
  register_cleanup_trap "$TEMP_DIR"
  cd "$TEMP_DIR"
  wget -O slack-desktop.deb https://downloads.slack-edge.com/releases/linux/slack-desktop-amd64.deb
  maybe_sudo dpkg -i slack-desktop.deb

  # Fix any dependency issues
  maybe_sudo apt install -f -y

  log_success "Slack installed successfully"
elif [[ "$PM" == "dnf" ]]; then
  # Fedora: Install via snap or flatpak
  log_info "On Fedora, Slack is best installed via Flatpak:"
  log_info "  flatpak install flathub com.slack.Slack"
  exit 0
else
  log_warning "Slack installation not supported for package manager: $PM"
  log_info "Please install Slack manually: https://slack.com/downloads"
fi
