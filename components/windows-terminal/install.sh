#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Installing Windows Terminal configuration"

if ! is_wsl; then
  log_warning "Windows Terminal configuration is only supported in WSL"
  exit 2
fi

WIN_HOME=$(get_windows_home)
if [[ -z "$WIN_HOME" ]]; then
  log_error "Could not determine Windows home directory"
  exit 1
fi

# Install Windows Terminal via winget if not present
WT_SETTINGS_DIR="$WIN_HOME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
if [[ ! -d "$WT_SETTINGS_DIR" ]]; then
  if has_winget; then
    install_winget "Microsoft.WindowsTerminal" "Windows Terminal"
    # Wait a moment for the settings directory to be created
    log_info "Waiting for Windows Terminal settings directory..."
    for i in {1..5}; do
      [[ -d "$WT_SETTINGS_DIR" ]] && break
      sleep 2
    done
  fi
fi

if [[ ! -d "$WT_SETTINGS_DIR" ]]; then
  log_warning "Windows Terminal settings directory not found"
  log_info "Please install and launch Windows Terminal first, then re-run this component"
  exit 1
fi

# Symlink or copy settings
SETTINGS_SRC="$SCRIPT_DIR/settings.json"
if [[ -f "$SETTINGS_SRC" ]]; then
  backup_file "$WT_SETTINGS_DIR/settings.json"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would copy settings.json to $WT_SETTINGS_DIR/"
  else
    cp "$SETTINGS_SRC" "$WT_SETTINGS_DIR/settings.json"
    log_success "Windows Terminal settings applied"
  fi
else
  log_info "No custom settings.json found in $SCRIPT_DIR"
  log_info "Create components/windows-terminal/settings.json to customize Windows Terminal"
fi

create_install_marker windows-terminal
log_success "Windows Terminal configured"
