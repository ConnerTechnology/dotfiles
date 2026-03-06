#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)

log_info "Uninstalling Docker..."

PM=$(get_package_manager)

if is_wsl; then
    log_info "To uninstall Docker Desktop on Windows, use: winget.exe uninstall Docker.DockerDesktop"
    exit 0
elif [[ "$OS" == "macos" ]]; then
    run_cmd brew uninstall --cask docker || true
elif [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
fi
