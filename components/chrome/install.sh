#!/usr/bin/env bash

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Google Chrome"

OS=$(detect_os)
ARCH=$(detect_arch)
PM=$(get_package_manager)

# WSL: Install Chrome on Windows side via winget
if is_wsl; then
  if [[ "${FORCE:-false}" != "true" ]] && is_winget_installed "Google.Chrome"; then
    log_info "Google Chrome is already installed on Windows"
    exit 0
  fi
  install_winget "Google.Chrome" "Google Chrome"
  log_success "Google Chrome installed on Windows via winget"
  create_install_marker chrome
  exit 0
fi

if [[ "$OS" == "macos" ]]; then
  check_installed_app "Google Chrome" && exit 0
else
  check_installed_cmd "google-chrome" "google-chrome --version" && exit 0
fi

log_info "Google Chrome is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
  install_brew_cask google-chrome
  log_success "Google Chrome installed successfully"
elif [[ "$PM" == "apt" ]]; then
  # Debian/Ubuntu: Download and install .deb package
  if [[ "$ARCH" != "amd64" ]]; then
    log_warning "Google Chrome installation not supported on $ARCH architecture"
    log_info "Install Chrome manually or use Chromium"
    exit 2
  fi
  ensure_wget_installed

  TEMP_DIR=$(mktemp -d)
  register_cleanup_trap "$TEMP_DIR"
  cd "$TEMP_DIR"
  wget -q -O google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  maybe_sudo dpkg -i google-chrome-stable_current_amd64.deb

  # Fix any dependency issues
  maybe_sudo apt install -f -y

  log_success "Google Chrome installed successfully: $(google-chrome --version)"
elif [[ "$PM" == "dnf" ]]; then
  # Fedora: Install via dnf
  log_info "Installing Google Chrome via dnf..."
  maybe_sudo dnf install -y fedora-workstation-repositories
  maybe_sudo dnf config-manager --set-enabled google-chrome
  maybe_sudo dnf install -y google-chrome-stable
  log_success "Google Chrome installed successfully"
else
  log_warning "Google Chrome installation not supported for package manager: $PM"
  log_info "Please install Chrome manually: https://www.google.com/chrome/"
fi
