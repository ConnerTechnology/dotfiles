#!/usr/bin/env bash

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Visual Studio Code"

OS=$(detect_os)
PM=$(get_package_manager)

# WSL: Install VS Code on Windows side via winget
if is_wsl; then
  if [[ "${FORCE:-false}" != "true" ]] && is_winget_installed "Microsoft.VisualStudioCode"; then
    log_info "Visual Studio Code is already installed on Windows"
    exit 0
  fi
  install_winget "Microsoft.VisualStudioCode" "Visual Studio Code"
  log_success "Visual Studio Code installed on Windows via winget"
  log_info "VS Code's WSL extension will allow editing WSL files seamlessly"
  create_install_marker vscode
  exit 0
fi

# Check if VS Code is already installed
if [[ "$OS" == "macos" ]]; then
  if [[ "${FORCE:-false}" != "true" ]] && { [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code >/dev/null 2>&1; }; then
    log_info "Visual Studio Code is already installed"
    if command -v code >/dev/null 2>&1; then
      log_info "Version: $(code --version | head -n1)"
    fi
    exit 0
  fi
else
  if [[ "${FORCE:-false}" != "true" ]] && command -v code >/dev/null 2>&1; then
    log_info "Visual Studio Code is already installed: $(code --version | head -n1)"
    exit 0
  fi
fi

log_info "Visual Studio Code is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
  install_brew_cask visual-studio-code
  log_success "Visual Studio Code installed successfully"
  log_info "Run 'code' from the terminal to open VS Code"
elif [[ "$PM" == "apt" ]]; then
  # Debian/Ubuntu: Add Microsoft repository and install via apt
  ensure_wget_installed
  ensure_gpg_installed

  # Add Microsoft GPG key and repository
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  maybe_sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  maybe_sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

  rm packages.microsoft.gpg

  maybe_sudo apt update
  maybe_sudo apt install -y code

  log_success "Visual Studio Code installed successfully: $(code --version | head -n1)"
elif [[ "$PM" == "dnf" ]]; then
  # Fedora: Add Microsoft repository and install via dnf
  log_info "Installing VS Code via dnf..."
  maybe_sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  maybe_sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  maybe_sudo dnf check-update
  maybe_sudo dnf install -y code
  log_success "Visual Studio Code installed successfully: $(code --version | head -n1)"
elif [[ "$PM" == "pacman" ]]; then
  # Arch: Install from AUR or use code-oss
  log_info "On Arch Linux, VS Code can be installed via:"
  log_info "  yay -S visual-studio-code-bin  (AUR)"
  log_info "  or: sudo pacman -S code  (open source version)"
  exit 0
else
  log_warning "VS Code installation not supported for package manager: $PM"
  log_info "Please install VS Code manually: https://code.visualstudio.com/"
fi
