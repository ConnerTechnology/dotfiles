#!/usr/bin/env bash

# ctdev gpu - Manage GPU driver signing for Secure Boot

# Source GPU utilities
source "${DOTFILES_ROOT}/lib/gpu.sh"

###############################################################################
# Subcommand: status
###############################################################################

gpu_status() {
    # macOS doesn't use Secure Boot/MOK signing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "GPU driver signing is not applicable on macOS."
        show_gpu_hardware_info "  "
        return 0
    fi

    log_step "GPU Signing Status"

    local issues=0

    # 1. Secure Boot
    if is_secure_boot_enabled; then
        log_check_pass "Secure Boot" "enabled"
    else
        log_check_pass "Secure Boot" "disabled (signing not required)"
        echo
        log_info "Secure Boot is disabled. GPU driver signing is not required."
        return 0
    fi

    # 2. NVIDIA driver + variant
    local driver_version variant
    driver_version=$(get_nvidia_driver_version)
    if is_nvidia_loaded; then
        variant=$(detect_nvidia_variant)
        log_check_pass "NVIDIA driver" "$driver_version ($variant kernel module)"
    else
        local backend
        backend=$(get_rendering_backend)
        if [[ "$backend" == "llvmpipe" ]]; then
            log_check_fail "NVIDIA driver" "not loaded (falling back to software rendering)"
        else
            log_check_fail "NVIDIA driver" "not loaded (using $backend)"
        fi
        issues=$((issues + 1))
    fi

    # 3. MOK key exists (only MOK.priv + MOK.der expected)
    if mok_key_exists; then
        log_check_pass "MOK key exists" "$MOK_DIR (MOK.priv, MOK.der)"
    else
        log_check_fail "MOK key" "not found at $MOK_DIR"
        issues=$((issues + 1))
    fi

    # 3b. Check for clutter files in MOK_DIR
    local clutter
    clutter=$(find_mok_clutter)
    if [[ -n "$clutter" ]]; then
        local clutter_names=""
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            clutter_names="${clutter_names:+$clutter_names, }$(basename "$file")"
        done <<< "$clutter"
        log_check_fail "MOK directory" "unnecessary files: $clutter_names"
        issues=$((issues + 1))
    fi

    # 4. DKMS framework.conf configuration
    if dkms_framework_conf_configured; then
        log_check_pass "DKMS framework.conf" "signing configured"
    elif dkms_signing_configured; then
        log_check_pass "DKMS signing" "configured (via conf.d)"
    else
        log_check_fail "DKMS signing" "not configured in $DKMS_FRAMEWORK_CONF"
        issues=$((issues + 1))
    fi

    # 5. MOK key enrolled
    if mok_key_enrolled; then
        log_check_pass "MOK key enrolled" "in firmware"
    else
        if mok_key_exists; then
            log_check_fail "MOK key" "exists but not enrolled (reboot required)"
        else
            log_check_fail "MOK key" "not enrolled"
        fi
        issues=$((issues + 1))
    fi

    # 6. Module signature matches enrolled MOK key
    if is_nvidia_loaded; then
        if module_sig_matches_enrolled; then
            log_check_pass "Module signature" "matches enrolled MOK key"
        else
            local signer
            signer=$(modinfo nvidia 2>/dev/null | grep "^signer:" | sed 's/^signer:[[:space:]]*//' || true)
            if [[ -n "$signer" ]]; then
                log_check_fail "Module signature" "signed by '$signer' (does not match MOK key)"
            else
                log_check_fail "Module signature" "unsigned"
            fi
            issues=$((issues + 1))
        fi
    fi

    echo

    if [[ $issues -gt 0 ]]; then
        log_warning "Found $issues issue(s)"
        echo
        echo "Run 'ctdev gpu setup' to configure driver signing."
        echo "Run 'ctdev gpu setup --recover' after a CMOS reset."
    else
        log_success "GPU signing is properly configured"
    fi

    return $issues
}

###############################################################################
# Subcommand: setup
###############################################################################

gpu_setup() {
    # macOS doesn't use Secure Boot/MOK signing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_error "GPU driver signing setup is not applicable on macOS."
        return 1
    fi

    log_step "GPU Signing Setup"
    echo

    # Pre-flight checks
    if ! is_secure_boot_enabled; then
        log_warning "Secure Boot is disabled. Driver signing is not required."
        echo
        read -rp "Continue anyway? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled."
            return 0
        fi
    fi

    # Check for NVIDIA DKMS
    local dkms_output
    dkms_output=$(dkms status 2>/dev/null || true)
    if ! echo "$dkms_output" | grep -q nvidia; then
        log_error "NVIDIA DKMS module not found."
        log_info "Install the NVIDIA driver first."
        log_info "Recommended: nvidia-driver-*-open (better Secure Boot support for RTX 30+)"
        return 1
    fi

    # Show current driver variant
    local variant
    variant=$(detect_nvidia_variant)
    if [[ "$variant" == "closed" ]]; then
        log_warning "Using closed-source NVIDIA kernel module."
        log_info "The open kernel module (nvidia-driver-*-open) is recommended for"
        log_info "RTX 30-series and newer GPUs with better Secure Boot compatibility."
        echo
    fi

    # Check if already fully configured
    if mok_key_exists && dkms_signing_configured && mok_key_enrolled && module_sig_matches_enrolled; then
        if [[ "${FORCE:-false}" != "true" ]]; then
            log_success "GPU signing is already fully configured."
            return 0
        fi
    fi

    # Step 1: Create MOK key pair
    log_step "Step 1: MOK Key Pair"
    if mok_key_exists && [[ "${FORCE:-false}" != "true" ]]; then
        log_info "MOK keys already exist at $MOK_DIR"
    else
        if create_mok_keypair; then
            log_success "Created MOK key pair at $MOK_DIR"
        else
            log_error "Failed to create MOK key pair"
            return 1
        fi
    fi

    # Clean up clutter files in MOK_DIR
    local clutter
    clutter=$(find_mok_clutter)
    if [[ -n "$clutter" ]]; then
        echo
        log_warning "Found unnecessary files in $MOK_DIR:"
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            echo "  $(basename "$file")"
        done <<< "$clutter"
        echo
        read -rp "Remove these files? [Y/n] " response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            clean_mok_clutter
            log_success "Cleaned up MOK directory"
        fi
    fi
    echo

    # Step 2: Configure DKMS framework.conf
    log_step "Step 2: DKMS Configuration"
    if dkms_framework_conf_configured && [[ "${FORCE:-false}" != "true" ]]; then
        log_info "DKMS framework.conf already configured"
    else
        if configure_dkms_framework_conf; then
            log_success "Configured $DKMS_FRAMEWORK_CONF"
        else
            log_warning "Could not configure framework.conf, trying conf.d approach"
            if configure_dkms_signing; then
                log_success "DKMS signing configured (via conf.d)"
            else
                log_error "Failed to configure DKMS signing"
                return 1
            fi
        fi
    fi
    echo

    # Step 3: Enroll MOK key
    local needs_reboot=false
    log_step "Step 3: MOK Key Enrollment"
    if mok_key_enrolled && [[ "${FORCE:-false}" != "true" ]]; then
        log_info "MOK key is already enrolled in firmware"
    else
        needs_reboot=true
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would run: mokutil --import $MOK_CERT"
        else
            echo "You will be prompted to create a one-time password."
            echo "Remember this password - you'll need it at the next reboot."
            echo
            if maybe_sudo mokutil --import "$MOK_CERT"; then
                log_success "MOK key queued for enrollment"
            else
                log_error "Failed to import MOK key"
                return 1
            fi
        fi
    fi
    echo

    # Step 4: DKMS rebuild to sign with the configured key
    log_step "Step 4: DKMS Rebuild"
    if module_sig_matches_enrolled && [[ "${FORCE:-false}" != "true" ]]; then
        log_info "NVIDIA modules already signed with correct key"
    else
        if dkms_rebuild_nvidia; then
            # Verify signature after rebuild
            local nvidia_module
            nvidia_module=$(find "/lib/modules/$(uname -r)" -name "nvidia.ko*" 2>/dev/null | head -1)
            if [[ -n "$nvidia_module" ]] && is_module_signed "$nvidia_module"; then
                log_success "NVIDIA modules rebuilt and signed"
            else
                log_warning "Modules rebuilt but signature could not be verified"
            fi
        else
            log_warning "DKMS rebuild failed, falling back to manual signing"
            sign_nvidia_modules
        fi
    fi
    echo

    # Step 5: Print reboot instructions (only if MOK enrollment is pending)
    if [[ "${DRY_RUN:-false}" != "true" ]] && [[ "$needs_reboot" == "true" ]]; then
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo "   REBOOT REQUIRED - MOK Enrollment"
        echo "═══════════════════════════════════════════════════════════════"
        echo
        echo "   1. Reboot your computer now"
        echo "   2. Watch for the blue 'MOK Manager' screen"
        echo "   3. Select 'Enroll MOK'"
        echo "   4. Select 'Continue'"
        echo "   5. Select 'Yes' to confirm"
        echo "   6. Enter the password you just set"
        echo "   7. Select 'Reboot'"
        echo
        echo "   After reboot, run 'ctdev gpu status' to verify."
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo
    fi

    return 0
}

###############################################################################
# Recovery mode (setup --recover)
###############################################################################

gpu_recover() {
    # macOS doesn't use Secure Boot/MOK signing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_error "GPU driver signing recovery is not applicable on macOS."
        return 1
    fi

    log_step "GPU Signing Recovery (CMOS Reset)"
    echo
    log_info "Re-enrolling existing MOK key after CMOS/firmware reset."
    echo

    # Keys must exist on disk for recovery
    if ! mok_key_exists; then
        log_error "No MOK keys found at $MOK_DIR"
        log_info "Cannot recover - keys do not exist on disk."
        log_info "Run 'ctdev gpu setup' instead to create new keys."
        return 1
    fi

    log_info "Found MOK certificate: $MOK_CERT"

    # Check if already enrolled (unnecessary recovery)
    if mok_key_enrolled; then
        log_info "MOK key is already enrolled in firmware. No recovery needed."
        return 0
    fi

    # Re-enroll the existing key
    log_step "Re-enrolling MOK key"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would run: mokutil --import $MOK_CERT"
    else
        echo "You will be prompted to create a one-time password."
        echo "Remember this password - you'll need it at the next reboot."
        echo
        if maybe_sudo mokutil --import "$MOK_CERT"; then
            log_success "MOK key queued for enrollment"
        else
            log_error "Failed to import MOK key"
            return 1
        fi
    fi
    echo

    # Print reboot instructions
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo "   REBOOT REQUIRED - MOK Re-Enrollment"
        echo "═══════════════════════════════════════════════════════════════"
        echo
        echo "   Your CMOS reset cleared the enrolled MOK key from firmware."
        echo "   The key files on disk are still intact."
        echo
        echo "   1. Reboot your computer now"
        echo "   2. Watch for the blue 'MOK Manager' screen"
        echo "   3. Select 'Enroll MOK'"
        echo "   4. Select 'Continue'"
        echo "   5. Select 'Yes' to confirm"
        echo "   6. Enter the password you just set"
        echo "   7. Select 'Reboot'"
        echo
        echo "   After reboot, run 'ctdev gpu status' to verify."
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo
    fi

    return 0
}

###############################################################################
# Help
###############################################################################

show_gpu_help() {
    cat << 'EOF'
ctdev gpu - Manage GPU driver signing for Secure Boot

Usage: ctdev gpu <subcommand> [OPTIONS]

Subcommands:
    status    Check secure boot and driver signing status
    setup     Configure MOK signing for NVIDIA drivers

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying
    -f, --force      Force re-run setup even if already configured
    --recover        Re-enroll MOK key after CMOS reset (use with setup)

Examples:
    ctdev gpu status              Check if driver signing is configured
    ctdev gpu setup               Set up MOK signing (interactive)
    ctdev gpu setup --recover     Re-enroll key after CMOS/firmware reset
    ctdev gpu setup --force       Re-run full setup even if configured
EOF
}

###############################################################################
# Main command dispatcher
###############################################################################

cmd_gpu() {
    local subcommand="${1:-}"

    if [[ -z "$subcommand" ]]; then
        show_gpu_help
        return 0
    fi

    shift

    case "$subcommand" in
        -h|--help)
            show_gpu_help
            return 0
            ;;
        status)
            gpu_status
            ;;
        setup)
            # Check for --recover flag
            local recover=false
            for arg in "$@"; do
                if [[ "$arg" == "--recover" ]]; then
                    recover=true
                fi
            done
            if [[ "$recover" == "true" ]]; then
                gpu_recover
            else
                gpu_setup
            fi
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"
            echo
            show_gpu_help
            return 1
            ;;
    esac
}
