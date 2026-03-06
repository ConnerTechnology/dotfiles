#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

if ! is_wsl; then
  log_warning "Windows Terminal configuration is only supported in WSL"
  exit 2
fi

log_info "Uninstalling Windows Terminal configuration..."
log_info "To uninstall Windows Terminal, use: winget.exe uninstall Microsoft.WindowsTerminal"

remove_install_marker windows-terminal
