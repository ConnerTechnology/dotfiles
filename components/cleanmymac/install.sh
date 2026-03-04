#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)

if [[ "$OS" != "macos" ]]; then
  log_warning "CleanMyMac installation not supported on $OS"
  log_info "For Linux, run: ctdev install bleachbit"
  exit 2
fi

log_info "Installing CleanMyMac"

if [[ "${FORCE:-false}" != "true" ]] && { [[ -d "/Applications/CleanMyMac.app" ]] || [[ -d "/Applications/CleanMyMac X.app" ]]; }; then
  log_info "CleanMyMac is already installed"
  exit 0
fi

install_brew_cask cleanmymac
log_success "CleanMyMac installed"
