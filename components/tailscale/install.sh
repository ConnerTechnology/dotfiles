#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Tailscale"

OS=$(detect_os)
PM=$(get_package_manager)

check_installed_cmd "tailscale" "tailscale --version" && exit 0

log_info "Tailscale is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
    ensure_brew_installed
    brew install --cask tailscale
    log_success "Tailscale installed"
elif [[ "$PM" == "apt" ]]; then
    ensure_curl_installed
    ensure_gpg_installed

    # Add Tailscale apt repository
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | maybe_sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | maybe_sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null

    maybe_sudo apt update
    maybe_sudo apt install -y tailscale

    maybe_sudo systemctl enable tailscaled 2>/dev/null || true
    maybe_sudo systemctl start tailscaled 2>/dev/null || true

    log_success "Tailscale installed: $(tailscale --version | head -n1)"
    log_info "Run 'sudo tailscale up' to authenticate"
else
    log_warning "Tailscale installation not supported for package manager: $PM"
    log_info "Please install manually: https://tailscale.com/download"
fi
