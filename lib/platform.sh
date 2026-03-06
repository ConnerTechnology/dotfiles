#!/usr/bin/env bash

# Platform detection and abstraction functions for ctdev CLI
# Part of the Conner Technology dotfiles

###############################################################################
# Platform Detection
###############################################################################

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "$ID"  # ubuntu, debian, arch, fedora, etc.
      else
        echo "linux"
      fi
      ;;
    Darwin*)
      echo "macos"
      ;;
    FreeBSD*)
      echo "freebsd"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Detect CPU architecture
# Returns: amd64, arm64
detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      echo "$arch"
      ;;
  esac
}

# Get Homebrew prefix (differs between Intel and Apple Silicon Macs)
get_brew_prefix() {
  if [[ "$(detect_os)" == "macos" ]]; then
    if [[ "$(detect_arch)" == "arm64" ]]; then
      echo "/opt/homebrew"
    else
      echo "/usr/local"
    fi
  else
    echo "/home/linuxbrew/.linuxbrew"
  fi
}

# Check if running on macOS
is_macos() {
  [[ "$(detect_os)" == "macos" ]]
}

# Check if running on Linux (includes WSL)
is_linux() {
  local os
  os=$(detect_os)
  [[ "$os" != "macos" && "$os" != "freebsd" && "$os" != "windows" && "$os" != "unknown" ]]
}

# Check if running inside Windows Subsystem for Linux
is_wsl() {
  [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null
}

# Get Windows home directory from WSL (e.g., /mnt/c/Users/username)
get_windows_home() {
  if ! is_wsl; then
    return 1
  fi
  local win_user
  win_user=$(wslpath -u "$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null)
  if [[ -d "$win_user" ]]; then
    echo "$win_user"
  else
    # Fallback: check common path
    local user
    user=$(cmd.exe /C 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
    if [[ -n "$user" && -d "/mnt/c/Users/$user" ]]; then
      echo "/mnt/c/Users/$user"
    else
      return 1
    fi
  fi
}

# Convert a WSL path to a Windows path
wsl_to_winpath() {
  local path="$1"
  wslpath -w "$path" 2>/dev/null
}

# Convert a Windows path to a WSL path
winpath_to_wsl() {
  local path="$1"
  wslpath -u "$path" 2>/dev/null
}

# Get the package manager for the current OS
get_package_manager() {
  local os
  os=$(detect_os)

  case "$os" in
    ubuntu|debian|linuxmint)
      echo "apt"
      ;;
    fedora|rhel|centos)
      echo "dnf"
      ;;
    arch|manjaro)
      echo "pacman"
      ;;
    macos)
      echo "brew"
      ;;
    freebsd)
      echo "pkg"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Check if winget is available (WSL only)
has_winget() {
  is_wsl && command -v winget.exe >/dev/null 2>&1
}

# Install a Windows application via winget from WSL
# Usage: install_winget "Package.Id" ["friendly name"]
install_winget() {
  local package_id="$1"
  local name="${2:-$package_id}"

  if ! is_wsl; then
    log_error "install_winget: Not running in WSL"
    return 1
  fi

  if ! has_winget; then
    log_error "winget.exe not found. Please install App Installer from the Microsoft Store."
    return 1
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would install via winget: $name ($package_id)"
    return 0
  fi

  log_info "Installing $name via winget..."
  winget.exe install --id "$package_id" --accept-source-agreements --accept-package-agreements --silent 2>/dev/null
}

# Check if a Windows application is installed via winget
# Usage: is_winget_installed "Package.Id"
is_winget_installed() {
  local package_id="$1"
  if ! has_winget; then
    return 1
  fi
  winget.exe list --id "$package_id" --accept-source-agreements 2>/dev/null | grep -qi "$package_id"
}

# Check if running in a dev container environment
is_devcontainer() {
  [[ "${REMOTE_CONTAINERS:-}" == "true" ]] || \
  [[ "${CODESPACES:-}" == "true" ]] || \
  [[ "${IN_DEV_CONTAINER:-}" == "true" ]]
}

# Helper to run command with sudo if not root
# Detects containers where sudo doesn't work (e.g., devcontainers with "no new privileges")
maybe_sudo() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  elif is_devcontainer; then
    # In devcontainers/Codespaces, sudo often fails due to security restrictions
    # Try without sudo first (might work if user has permissions), otherwise warn
    if "$@" 2>/dev/null; then
      return 0
    else
      log_warning "Cannot run '$1' - sudo unavailable in container. You may need to install packages in your Dockerfile."
      return 1
    fi
  else
    sudo "$@"
  fi
}

# Install a package using the appropriate package manager
install_package() {
  local package="$1"
  local os
  local pm

  os=$(detect_os)
  pm=$(get_package_manager)

  log_debug "Installing $package on $os using $pm"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would install package: $package"
    return 0
  fi

  case "$pm" in
    apt)
      maybe_sudo apt update
      maybe_sudo apt install -y "$package"
      ;;
    dnf)
      maybe_sudo dnf install -y "$package"
      ;;
    pacman)
      maybe_sudo pacman -S --noconfirm "$package"
      ;;
    brew)
      brew install "$package"
      ;;
    pkg)
      maybe_sudo pkg install -y "$package"
      ;;
    *)
      log_error "Unsupported package manager or OS: $pm ($os)"
      log_error "Please install $package manually"
      return 1
      ;;
  esac
}
