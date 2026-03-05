#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Solaar (Logitech Unifying/Bolt receiver manager)"

if [[ "${FORCE:-false}" != "true" ]] && command -v solaar >/dev/null 2>&1; then
    log_info "Solaar already installed"
    exit 0
fi

OS=$(detect_os)
if [[ "$OS" == "macos" ]]; then
    log_info "Solaar is Linux-only. Use Logi Options+ on macOS."
    exit 2
fi

install_package solaar

log_success "Solaar installed"
