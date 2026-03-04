#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for ctdev dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/ConnerTechnology/dotfiles/main/install.sh | bash

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REPO_URL="https://github.com/ConnerTechnology/dotfiles.git"
CTDEV_SYMLINK="$HOME/.local/bin/ctdev"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check for git
if ! command -v git >/dev/null 2>&1; then
    error "Git is required. Please install git first."
fi

echo
echo "  ┌─────────────────────────────────────┐"
echo "  │  ctdev dotfiles installer           │"
echo "  └─────────────────────────────────────┘"
echo

# Clone or update repo
if [[ -d "$DOTFILES_DIR" ]]; then
    info "Dotfiles directory exists at $DOTFILES_DIR"
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Updating existing installation..."
        cd "$DOTFILES_DIR"
        git pull --rebase || warn "Could not update, continuing with existing version"
    else
        error "$DOTFILES_DIR exists but is not a git repo. Please remove it or set DOTFILES_DIR."
    fi
else
    info "Cloning dotfiles to $DOTFILES_DIR..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# Create ~/.local/bin if it doesn't exist
if [[ ! -d "$HOME/.local/bin" ]]; then
    info "Creating ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
fi

# Create symlink to ctdev
if [[ -L "$CTDEV_SYMLINK" ]]; then
    info "Updating ctdev symlink..."
    rm -f "$CTDEV_SYMLINK"
fi

ln -sf "$DOTFILES_DIR/ctdev" "$CTDEV_SYMLINK"
success "ctdev symlinked to $CTDEV_SYMLINK"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    warn "~/.local/bin is not in your PATH"
    echo
    echo "  Add this to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
fi

success "ctdev is now installed!"
echo
echo "  Next steps:"
echo "    1. Restart your terminal (or add ~/.local/bin to PATH)"
echo "    2. Run: ctdev components install zsh git  # Install shell config"
echo "    3. Run: ctdev components list             # See all components"
echo
echo "  Run 'ctdev --help' for more options."
echo
