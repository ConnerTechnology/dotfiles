#!/usr/bin/env bash
set -euo pipefail

# Uninstall script for ctdev dotfiles
# Usage: ./uninstall.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTDEV_SYMLINK="$HOME/.local/bin/ctdev"
CTDEV_CONFIG_DIR="$HOME/.config/ctdev"

echo
echo "  ┌─────────────────────────────────────┐"
echo "  │  ctdev uninstaller                  │"
echo "  └─────────────────────────────────────┘"
echo

# Check if ctdev is installed
if [[ ! -L "$CTDEV_SYMLINK" ]] && [[ ! -d "$CTDEV_CONFIG_DIR" ]]; then
    info "ctdev does not appear to be installed"
    exit 0
fi

# Ask about uninstalling components first
if [[ -t 0 ]]; then
    printf "Uninstall all components first? [y/N] "
    if read -r answer && [[ "$answer" =~ ^[Yy]$ ]]; then
        if [[ -x "$SCRIPT_DIR/ctdev" ]]; then
            "$SCRIPT_DIR/ctdev" components uninstall
        else
            warn "Could not run ctdev uninstall (ctdev not executable)"
        fi
    fi
fi

echo

# Remove ctdev symlink
if [[ -L "$CTDEV_SYMLINK" ]]; then
    info "Removing ctdev symlink..."
    rm -f "$CTDEV_SYMLINK"
    success "Removed $CTDEV_SYMLINK"
else
    info "No ctdev symlink found at $CTDEV_SYMLINK"
fi

# Remove config directory (installation markers)
if [[ -d "$CTDEV_CONFIG_DIR" ]]; then
    info "Removing ctdev config directory..."
    rm -rf "$CTDEV_CONFIG_DIR"
    success "Removed $CTDEV_CONFIG_DIR"
else
    info "No ctdev config directory found"
fi

echo
success "ctdev has been uninstalled"
echo
echo "  The dotfiles repo still exists at: $SCRIPT_DIR"
echo "  To remove it completely: rm -rf $SCRIPT_DIR"
echo
