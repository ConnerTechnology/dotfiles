#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

OS=$(detect_os)

if [[ "$OS" == "macos" ]]; then
    exit 2
fi

PM=$(get_package_manager)

log_info "Uninstalling earlyoom..."

run_cmd maybe_sudo systemctl disable --now earlyoom || true

if [[ "$PM" == "apt" ]]; then
    run_cmd maybe_sudo apt remove -y earlyoom || true
elif [[ "$PM" == "dnf" ]]; then
    run_cmd maybe_sudo dnf remove -y earlyoom || true
elif [[ "$PM" == "pacman" ]]; then
    run_cmd maybe_sudo pacman -R --noconfirm earlyoom || true
fi
