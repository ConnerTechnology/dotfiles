#!/usr/bin/env bash

# ctdev install - Install specific components

OS=$(detect_os)

cmd_install() {
    local components=()

    # Parse subcommand arguments, filtering out flags that were already processed
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
        echo "Usage: ctdev install <component...>"
        echo ""
        echo "Available components:"
        list_components | while read -r name; do
            local desc
            desc=$(get_component_description "$name")
            printf "  %-20s %s\n" "$name" "$desc"
        done
        return 1
    fi

    # Validate specified components
    if ! validate_components "${components[@]}"; then
        return 1
    fi

    log_step "Installing components: ${components[*]}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY-RUN MODE: No changes will be made"
    fi

    if [[ "${FORCE:-false}" == "true" ]]; then
        log_warning "FORCE MODE: Re-running install scripts for all specified components"
    fi

    log_info "Detected OS: $OS"
    echo

    local failed=()
    local installed=()
    local skipped=()
    local already_installed=()

    for component in "${components[@]}"; do
        local script
        script=$(get_component_install_script "$component")

        if [[ ! -f "$script" ]]; then
            log_warning "Install script not found for $component: $script"
            failed+=("$component")
            continue
        fi

        if [[ "${FORCE:-false}" != "true" ]] && is_component_installed "$component"; then
            log_info "$component is already installed"
            already_installed+=("$component")
        else
            log_step "Installing $component"

            local exit_code=0
            bash "$script" || exit_code=$?

            case $exit_code in
                0)
                    installed+=("$component")
                    create_install_marker "$component"
                    ;;
                2)
                    # Exit code 2 = skipped (not supported on this platform)
                    skipped+=("$component")
                    ;;
                *)
                    log_error "Failed to install $component"
                    failed+=("$component")
                    ;;
            esac
        fi

        echo ""
    done

    # Summary
    log_step "Complete"

    if [[ ${#installed[@]} -gt 0 ]]; then
        log_success "Installed: ${installed[*]}"
    fi

    if [[ ${#already_installed[@]} -gt 0 ]]; then
        log_info "Already installed: ${already_installed[*]}"
    fi

    if [[ ${#skipped[@]} -gt 0 ]]; then
        log_info "Skipped (not supported): ${skipped[*]}"
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed: ${failed[*]}"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "This was a dry-run. Run without --dry-run to apply changes."
    elif [[ ${#installed[@]} -gt 0 ]]; then
        log_info "You may need to restart your shell for some changes to take effect"
    fi

    return 0
}
