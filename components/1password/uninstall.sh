#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)

log_info "Uninstalling 1Password..."

PM=$(get_package_manager)

if is_wsl; then
    log_info "To uninstall 1Password on Windows, use: winget.exe uninstall AgileBits.1Password"
    exit 0
elif [[ "$OS" == "macos" ]]; then
    if [[ -d "/Applications/1Password.app" ]]; then
        run_cmd brew uninstall --cask 1password || log_warning "Could not uninstall via brew"
    fi
elif [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo apt remove -y 1password || true
fi
