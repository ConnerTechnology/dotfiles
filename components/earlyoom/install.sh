#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing earlyoom (OOM killer)"

OS=$(detect_os)

if [[ "$OS" == "macos" ]]; then
    log_warning "earlyoom is Linux-only, skipping on macOS"
    exit 2
fi

PM=$(get_package_manager)

check_installed_cmd "earlyoom" "earlyoom --version" && exit 0

log_info "earlyoom is not installed. Installing..."

if [[ "$PM" == "apt" ]]; then
    maybe_sudo apt update
    maybe_sudo apt install -y earlyoom
elif [[ "$PM" == "dnf" ]]; then
    maybe_sudo dnf install -y earlyoom
elif [[ "$PM" == "pacman" ]]; then
    maybe_sudo pacman -S --noconfirm earlyoom
else
    log_warning "earlyoom installation not supported for package manager: $PM"
    exit 1
fi

maybe_sudo systemctl enable --now earlyoom
log_success "earlyoom installed and enabled"
