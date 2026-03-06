#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

if ! is_wsl; then
  log_warning "Windows setup is only supported in WSL"
  exit 2
fi

log_info "Uninstalling Windows setup..."
log_warning "Registry and system changes cannot be automatically reverted"
log_info "Re-enable settings manually via Windows Settings or Group Policy Editor"

remove_install_marker windows-setup
