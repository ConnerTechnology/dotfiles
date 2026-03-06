#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

log_info "Applying Windows system configuration"

if ! is_wsl; then
  log_warning "Windows setup is only supported in WSL"
  exit 2
fi

# All PowerShell scripts need to run elevated
run_ps() {
  local script="$1"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would run PowerShell script: $(basename "$script")"
    return 0
  fi
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wsl_to_winpath "$script")" 2>/dev/null
}

###############################################################################
# Step 1: Remove bloatware
###############################################################################
log_step "Removing Windows bloatware"
run_ps "$SCRIPT_DIR/scripts/remove-bloatware.ps1"

###############################################################################
# Step 2: Privacy and telemetry settings
###############################################################################
log_step "Applying privacy and telemetry settings"
run_ps "$SCRIPT_DIR/scripts/privacy-tweaks.ps1"

###############################################################################
# Step 3: Performance tweaks
###############################################################################
log_step "Applying performance tweaks"
run_ps "$SCRIPT_DIR/scripts/performance-tweaks.ps1"

###############################################################################
# Step 4: Windows Update settings
###############################################################################
log_step "Configuring Windows Update settings"
run_ps "$SCRIPT_DIR/scripts/update-settings.ps1"

###############################################################################
# Step 5: Common settings and UI tweaks
###############################################################################
log_step "Applying common Windows settings"
run_ps "$SCRIPT_DIR/scripts/common-settings.ps1"

create_install_marker windows-setup
log_success "Windows system configuration applied"
log_info "Some changes may require a restart to take effect"
