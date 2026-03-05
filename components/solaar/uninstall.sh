#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)
PM=$(get_package_manager)

log_info "Uninstalling Solaar..."

if [[ "$OS" == "macos" ]]; then
    exit 2
elif [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo apt remove -y solaar || true
fi
