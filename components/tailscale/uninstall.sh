#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)
PM=$(get_package_manager)

log_info "Uninstalling Tailscale..."

if [[ "$OS" == "macos" ]]; then
    run_cmd brew uninstall --cask tailscale || true
elif [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo systemctl stop tailscaled 2>/dev/null || true
    run_cmd maybe_sudo systemctl disable tailscaled 2>/dev/null || true
    run_cmd maybe_sudo apt remove -y tailscale || true
    run_cmd maybe_sudo rm -f /etc/apt/sources.list.d/tailscale.list
    run_cmd maybe_sudo rm -f /usr/share/keyrings/tailscale-archive-keyring.gpg
fi
