#!/usr/bin/env bash

# ctdev components - Manage installable components
# Subcommands: list, install, uninstall

OS=$(detect_os)

# Define GREY for list output (not in logging.sh)
GREY='\033[0;90m'

# ============================================================================
# Subcommand: list
# ============================================================================

components_list() {
    echo
    log_step "Components"
    echo

    local name _desc _script
    for component in "${COMPONENTS[@]}"; do
        IFS=':' read -r name _desc _script <<< "$component"

        local status_text status_color

        # Check OS support first
        if ! is_component_supported "$name"; then
            status_text="not supported"
            status_color="$GREY"
        elif is_component_installed "$name"; then
            # Check if updates available (for components that support it)
            if has_updates_available "$name"; then
                status_text="installed (update available)"
                status_color="$YELLOW"
            else
                status_text="installed"
                status_color="$GREEN"
            fi
        else
            status_text="not installed"
            status_color="$GREY"
        fi

        printf "  %-20s ${status_color}%s${NC}\n" "$name" "$status_text"
    done

    # Chrome Web Apps hint (Linux only, Chrome installed)
    if [[ "$OSTYPE" != "darwin"* ]] && command -v google-chrome >/dev/null 2>&1; then
        echo
        log_step "Chrome Web Apps"
        echo
        echo "  Some apps work best as Chrome web apps. To install:"
        echo "  Menu (three dots) → Cast, save, and share → Install page as app"
    fi

    echo
}

# Check if a component has updates available
# Returns 0 if updates available, 1 otherwise
has_updates_available() {
    local component="$1"

    case "$component" in
        zsh)
            # Check if any zsh-related git repos are behind
            for repo in "$HOME/.oh-my-zsh" "$HOME/.zsh/pure"; do
                if [[ -d "$repo/.git" ]]; then
                    local behind
                    behind=$(git -C "$repo" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || continue
                    if [[ "$behind" -gt 0 ]]; then
                        return 0
                    fi
                fi
            done
            ;;
        node)
            if [[ -d "$HOME/.nodenv/.git" ]]; then
                local behind
                behind=$(git -C "$HOME/.nodenv" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || return 1
                if [[ "$behind" -gt 0 ]]; then
                    return 0
                fi
            fi
            ;;
        ruby)
            if [[ -d "$HOME/.rbenv/.git" ]]; then
                local behind
                behind=$(git -C "$HOME/.rbenv" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || return 1
                if [[ "$behind" -gt 0 ]]; then
                    return 0
                fi
            fi
            ;;
    esac

    return 1
}

# ============================================================================
# Subcommand: install
# ============================================================================

components_install() {
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
        echo "Usage: ctdev components install <component...>"
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

# ============================================================================
# Subcommand: uninstall
# ============================================================================

# Get path to component uninstall script
get_component_uninstall_script() {
    local component="$1"
    local script="${DOTFILES_ROOT}/components/${component}/uninstall.sh"
    if [[ -x "$script" ]]; then
        echo "$script"
        return 0
    fi
    return 1
}

# Run uninstall for a component
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

components_uninstall() {
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
        echo "Usage: ctdev components uninstall <component...>"
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

# ============================================================================
# Main command dispatcher
# ============================================================================

cmd_components() {
    local subcommand="${1:-}"

    if [[ -z "$subcommand" ]]; then
        show_components_help
        return 0
    fi

    shift

    case "$subcommand" in
        -h|--help)
            show_components_help
            return 0
            ;;
        list)
            components_list
            ;;
        install)
            components_install "$@"
            ;;
        uninstall)
            components_uninstall "$@"
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"
            echo ""
            show_components_help
            return 1
            ;;
    esac
}
