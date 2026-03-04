#!/usr/bin/env bash

# ctdev uninstall - Remove installed components
# Dispatches to components/<name>/uninstall.sh
#
# Exit codes from component scripts:
#   0: success
#   2: unsupported on this OS (skip)
#   other: failure

# ============================================================================
# Get path to component uninstall script
# ============================================================================

get_component_uninstall_script() {
    local component="$1"
    local script="${DOTFILES_ROOT}/components/${component}/uninstall.sh"
    if [[ -x "$script" ]]; then
        echo "$script"
        return 0
    fi
    return 1
}

# ============================================================================
# Run uninstall for a component
# ============================================================================

run_uninstall() {
    local component="$1"
    local script

    script=$(get_component_uninstall_script "$component")
    if [[ -z "$script" ]]; then
        log_warning "No uninstall script for: $component"
        return 1
    fi

    # Run the uninstall script
    "$script"
}

# ============================================================================
# Main command
# ============================================================================

cmd_uninstall() {
    local components=()

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -h|--help|-v|--verbose|-n|--dry-run|-f|--force)
                # Already handled by main dispatcher
                ;;
            *)
                components+=("$arg")
                ;;
        esac
    done

    # Require at least one component
    if [[ ${#components[@]} -eq 0 ]]; then
        log_error "No components specified"
        echo ""
        echo "Usage: ctdev uninstall <component...>"
        echo ""
        echo "Installed components:"
        list_installed_components | while read -r name; do
            echo "  $name"
        done
        return 1
    fi

    # Validate specified components
    if ! validate_components "${components[@]}"; then
        return 1
    fi

    log_step "Uninstalling: ${components[*]}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY-RUN MODE: No changes will be made"
    fi

    echo

    local uninstalled=()
    local skipped=()
    local failed=()

    for component in "${components[@]}"; do
        if ! is_component_installed "$component"; then
            log_info "$component is not installed"
            continue
        fi

        local exit_code=0
        run_uninstall "$component" || exit_code=$?

        case "$exit_code" in
            0)
                remove_install_marker "$component"
                uninstalled+=("$component")
                ;;
            2)
                # Unsupported on this OS
                skipped+=("$component")
                ;;
            *)
                failed+=("$component")
                ;;
        esac
        echo
    done

    # Summary
    log_step "Uninstall Complete"

    if [[ ${#uninstalled[@]} -gt 0 ]]; then
        log_success "Uninstalled: ${uninstalled[*]}"
    fi

    if [[ ${#skipped[@]} -gt 0 ]]; then
        log_info "Skipped (unsupported): ${skipped[*]}"
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed: ${failed[*]}"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "This was a dry-run. Run without --dry-run to apply changes."
    else
        log_info "Restart your shell for changes to take effect"
    fi

    return 0
}
