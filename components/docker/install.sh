#!/usr/bin/env bash

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Docker"

OS=$(detect_os)
PM=$(get_package_manager)

# WSL: Install Docker Desktop on Windows side via winget
if is_wsl; then
  if [[ "${FORCE:-false}" != "true" ]] && command -v docker >/dev/null 2>&1; then
    log_info "Docker is already available in WSL: $(docker --version)"
    exit 0
  fi
  if [[ "${FORCE:-false}" != "true" ]] && is_winget_installed "Docker.DockerDesktop"; then
    log_info "Docker Desktop is already installed on Windows"
    log_info "Enable WSL integration in Docker Desktop settings to use docker from WSL"
    exit 0
  fi
  install_winget "Docker.DockerDesktop" "Docker Desktop"
  log_success "Docker Desktop installed on Windows via winget"
  log_info "Enable WSL integration in Docker Desktop > Settings > Resources > WSL Integration"
  create_install_marker docker
  exit 0
fi

check_installed_cmd "docker" "docker --version" && exit 0

log_info "Docker is not installed. Installing..."

if [[ "$OS" == "macos" ]]; then
  # macOS: Install via Homebrew cask
  install_brew_cask docker
  log_success "Docker installed successfully"
  log_info "Please launch Docker.app to complete setup"
elif [[ "$PM" == "apt" ]]; then
  # Debian/Ubuntu: Install Docker Engine via apt (official method from docs.docker.com)
  ensure_curl_installed

  log_info "Installing Docker Engine for Debian/Ubuntu..."

  # Install prerequisites
  maybe_sudo apt update
  maybe_sudo apt install -y ca-certificates curl

  # Add Docker's official GPG key
  maybe_sudo install -m 0755 -d /etc/apt/keyrings
  maybe_sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  maybe_sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Get Ubuntu codename (handles derivatives like Linux Mint)
  CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

  # Add the repository to apt sources
  echo "Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc" | maybe_sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

  # Install Docker packages
  maybe_sudo apt update
  maybe_sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add current user to docker group (if not root)
  if [[ $EUID -ne 0 ]]; then
    maybe_sudo usermod -aG docker "$USER"
    log_info "Added $USER to docker group. Log out and back in for this to take effect."
  fi

  log_success "Docker installed: $(docker --version)"
elif [[ "$PM" == "dnf" ]]; then
  # Fedora/RHEL: Install Docker via dnf
  log_info "Installing Docker Engine for Fedora/RHEL..."
  maybe_sudo dnf -y install dnf-plugins-core
  maybe_sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  maybe_sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  maybe_sudo systemctl start docker
  maybe_sudo systemctl enable docker

  if [[ $EUID -ne 0 ]]; then
    maybe_sudo usermod -aG docker "$USER"
    log_info "Added $USER to docker group. Log out and back in for this to take effect."
  fi

  log_success "Docker installed: $(docker --version)"
elif [[ "$PM" == "pacman" ]]; then
  # Arch Linux: Install Docker via pacman
  log_info "Installing Docker Engine for Arch Linux..."
  maybe_sudo pacman -S --noconfirm docker docker-compose
  maybe_sudo systemctl start docker
  maybe_sudo systemctl enable docker

  if [[ $EUID -ne 0 ]]; then
    maybe_sudo usermod -aG docker "$USER"
    log_info "Added $USER to docker group. Log out and back in for this to take effect."
  fi

  log_success "Docker installed: $(docker --version)"
else
  log_warning "Docker installation not supported for package manager: $PM"
  log_info "Please install Docker manually: https://docs.docker.com/engine/install/"
fi
