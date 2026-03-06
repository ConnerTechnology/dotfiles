#!/usr/bin/env bash

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing 1Password"

OS=$(detect_os)
PM=$(get_package_manager)

# WSL: Install 1Password on Windows side via winget
if is_wsl; then
  if [[ "${FORCE:-false}" != "true" ]] && is_winget_installed "AgileBits.1Password"; then
    log_info "1Password is already installed on Windows"
    exit 0
  fi
  install_winget "AgileBits.1Password" "1Password"
  log_success "1Password installed on Windows via winget"
  create_install_marker 1password
  exit 0
fi

if [[ "$OS" == "macos" ]]; then
  check_installed_app "1Password" && exit 0
else
  check_installed_cmd "1password" && exit 0
fi

log_info "1Password is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
  install_brew_cask 1password
  log_success "1Password installed successfully"
elif [[ "$PM" == "apt" ]]; then
  # Debian/Ubuntu: Install via official 1Password repository
  ensure_curl_installed
  ensure_gpg_installed

  log_info "Adding 1Password repository..."
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | maybe_sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | maybe_sudo tee /etc/apt/sources.list.d/1password.list
  maybe_sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | maybe_sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
  maybe_sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | maybe_sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

  maybe_sudo apt update
  maybe_sudo apt install -y 1password

  log_success "1Password installed successfully"
else
  log_warning "1Password installation not automated for package manager: $PM"
  log_info "Please install 1Password manually: https://1password.com/downloads/linux/"
fi
