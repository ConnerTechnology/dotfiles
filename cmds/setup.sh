#!/usr/bin/env bash

# ctdev setup - Orchestrate a fresh system setup

OS=$(detect_os)

###############################################################################
# Help
###############################################################################

show_setup_help() {
    cat << 'EOF'
ctdev setup - Set up a fresh system

Usage: ctdev setup [OPTIONS]

Runs all setup steps in the correct order for the current OS.

Linux Mint steps:
    1. System update (apt upgrade)
    2. GPU driver signing setup (NVIDIA + Secure Boot)
    3. System configuration (GRUB, services, desktop settings)
    4. Kernel cleanup (remove old kernels)
    5. APT repository audit (interactive)

macOS steps:
    1. System update (brew upgrade)
    2. System configuration (defaults)

Options:
    -h, --help           Show this help message
    -n, --dry-run        Preview changes without applying
    -f, --force          Force re-run even if already configured
    --skip-update        Skip system update step
    --skip-gpu           Skip GPU setup step (Linux only)
    --skip-configure     Skip system configuration step
    --skip-cleanup       Skip cleanup steps (Linux only)

Examples:
    ctdev setup                     Run full setup
    ctdev setup --dry-run           Preview all changes
    ctdev setup --skip-update       Skip system update
    ctdev setup --skip-gpu          Skip GPU signing setup
EOF
}

###############################################################################
# Main command
###############################################################################

cmd_setup() {
    local skip_update=false
    local skip_gpu=false
    local skip_configure=false
    local skip_cleanup=false

    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                show_setup_help
                return 0
                ;;
            --skip-update)    skip_update=true ;;
            --skip-gpu)       skip_gpu=true ;;
            --skip-configure) skip_configure=true ;;
            --skip-cleanup)   skip_cleanup=true ;;
        esac
    done

    local step=1

    # =========================================================================
    # Step 1: System update
    # =========================================================================
    if [[ "$skip_update" == "true" ]]; then
        log_info "Step $step: System update (skipped)"
    else
        log_step "Step $step: System Update"
        # shellcheck source=cmds/update.sh
        source "$DOTFILES_ROOT/cmds/update.sh"
        cmd_update -y
    fi
    step=$((step + 1))
    echo

    # =========================================================================
    # Step 2: GPU setup (Linux only)
    # =========================================================================
    if [[ "$OS" != "macos" ]]; then
        if [[ "$skip_gpu" == "true" ]]; then
            log_info "Step $step: GPU setup (skipped)"
        else
            log_step "Step $step: GPU Driver Signing"
            # shellcheck source=lib/gpu.sh
            source "$DOTFILES_ROOT/lib/gpu.sh"
            # shellcheck source=cmds/gpu.sh
            source "$DOTFILES_ROOT/cmds/gpu.sh"

            if command -v lspci >/dev/null 2>&1 && lspci | grep -qi nvidia; then
                if is_secure_boot_enabled; then
                    gpu_setup
                else
                    log_info "Secure Boot is disabled, skipping GPU driver signing"
                fi
            else
                log_info "No NVIDIA hardware detected, skipping GPU driver signing"
            fi
        fi
        step=$((step + 1))
        echo
    fi

    # =========================================================================
    # Step 3: System configuration
    # =========================================================================
    if [[ "$skip_configure" == "true" ]]; then
        log_info "Step $step: System configuration (skipped)"
    else
        log_step "Step $step: System Configuration"
        # shellcheck source=cmds/configure.sh
        source "$DOTFILES_ROOT/cmds/configure.sh"

        case "$OS" in
            linuxmint)
                configure_linux_mint
                ;;
            macos)
                configure_macos
                ;;
            *)
                log_warning "No system configuration available for $OS"
                ;;
        esac
    fi
    step=$((step + 1))
    echo

    # =========================================================================
    # Step 4: Kernel cleanup (Linux only)
    # =========================================================================
    if [[ "$OS" != "macos" ]]; then
        # shellcheck source=cmds/cleanup.sh
        source "$DOTFILES_ROOT/cmds/cleanup.sh"

        if [[ "$skip_cleanup" == "true" ]]; then
            log_info "Step $step: Kernel cleanup (skipped)"
        else
            log_step "Step $step: Kernel Cleanup"
            cleanup_kernels
        fi
        step=$((step + 1))
        echo

        # =====================================================================
        # Step 5: APT cleanup (Linux only)
        # =====================================================================
        if [[ "$skip_cleanup" == "true" ]]; then
            log_info "Step $step: APT cleanup (skipped)"
        else
            log_step "Step $step: APT Repository Audit"
            cleanup_apt
        fi
        step=$((step + 1))
        echo
    fi

    # =========================================================================
    # Done
    # =========================================================================
    log_success "Setup complete!"
    log_info "Some changes may require a logout or reboot to take full effect."
}
