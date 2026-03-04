#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing OpenAI Codex CLI"

check_installed_cmd "codex" && exit 0

OS=$(detect_os)

if [[ "$OS" == "macos" ]]; then
    # On macOS, prefer Homebrew cask
    install_brew_cask codex
else
    # On Linux, install via npm (requires Node.js 18+)
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js is required to install Codex CLI"
        log_info "Install Node.js first: ctdev install node"
        exit 1
    fi

    node_version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ "$node_version" -lt 18 ]]; then
        log_error "Node.js 18+ is required (found v$node_version)"
        log_info "Update Node.js: ctdev install node --force"
        exit 1
    fi

    log_info "Installing Codex CLI via npm..."
    run_cmd npm install -g @openai/codex
fi

log_success "Codex CLI installed"

log_success "OpenAI Codex CLI installation complete"
