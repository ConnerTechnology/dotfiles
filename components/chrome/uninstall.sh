#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)

log_info "Uninstalling Chrome..."

PM=$(get_package_manager)

if is_wsl; then
    log_info "To uninstall Chrome on Windows, use: winget.exe uninstall Google.Chrome"
    exit 0
elif [[ "$OS" == "macos" ]]; then
    run_cmd brew uninstall --cask google-chrome || log_warning "Could not uninstall via brew"
elif [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo apt remove -y google-chrome-stable || true
fi
