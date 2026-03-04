#!/usr/bin/env bash

# ctdev cleanup - Clean up system resources

OS=$(detect_os)
PKG_MGR=$(get_package_manager)

###############################################################################
# Help
###############################################################################

show_cleanup_help() {
    cat << 'EOF'
ctdev cleanup - Clean up system resources

Usage: ctdev cleanup <subcommand> [OPTIONS]

Subcommands:
    kernels   Remove old kernel versions (keep current + one previous)
    apt       Audit and clean APT repositories (interactive)

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying
    -f, --force      Skip confirmation prompts

Examples:
    ctdev cleanup kernels             Remove old kernels
    ctdev cleanup kernels --dry-run   Preview kernel cleanup
    ctdev cleanup apt                 Interactive APT repo audit
EOF
}

###############################################################################
# Subcommand: kernels
###############################################################################

cleanup_kernels() {
    if [[ "$OS" == "macos" ]]; then
        log_info "Kernel cleanup is not applicable on macOS"
        return 0
    fi

    if [[ "$PKG_MGR" != "apt" ]]; then
        log_warning "Kernel cleanup is only supported on apt-based systems"
        return 0
    fi

    log_step "Kernel Cleanup"
    echo

    # Get current kernel version
    local current_kernel
    current_kernel=$(uname -r)
    log_info "Current kernel: $current_kernel"

    # Get all installed kernel image packages
    local installed_kernels
    installed_kernels=$(dpkg --list | grep -E "^ii\s+linux-image-[0-9]" | awk '{print $2}' | sort -V)

    if [[ -z "$installed_kernels" ]]; then
        log_info "No kernel image packages found"
        return 0
    fi

    # Show installed kernels
    echo
    log_step "Installed kernels:"
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if echo "$pkg" | grep -q "$current_kernel"; then
            echo "  $pkg  (current)"
        else
            echo "  $pkg"
        fi
    done <<< "$installed_kernels"
    echo

    # Find the current kernel's package name
    local current_pkg=""
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if echo "$pkg" | grep -q "$current_kernel"; then
            current_pkg="$pkg"
            break
        fi
    done <<< "$installed_kernels"

    if [[ -z "$current_pkg" ]]; then
        log_warning "Could not find package for current kernel $current_kernel"
        return 1
    fi

    # Determine which to keep: current + one previous
    local keep_pkgs=()
    local prev_pkg=""
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if [[ "$pkg" == "$current_pkg" ]]; then
            if [[ -n "$prev_pkg" ]]; then
                keep_pkgs+=("$prev_pkg")
            fi
            keep_pkgs+=("$current_pkg")
            break
        fi
        prev_pkg="$pkg"
    done <<< "$installed_kernels"

    # Build removal list
    local remove_pkgs=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local should_keep=false
        for keep in "${keep_pkgs[@]}"; do
            if [[ "$pkg" == "$keep" ]]; then
                should_keep=true
                break
            fi
        done
        if [[ "$should_keep" == "false" ]]; then
            remove_pkgs+=("$pkg")
        fi
    done <<< "$installed_kernels"

    if [[ ${#remove_pkgs[@]} -eq 0 ]]; then
        log_success "No old kernels to remove"
        return 0
    fi

    # Show what will be kept and removed
    log_step "Keeping:"
    for pkg in "${keep_pkgs[@]}"; do
        local version
        version="${pkg//linux-image-/}"
        echo "  $pkg"
        echo "  linux-headers-$version (if installed)"
    done
    echo

    log_step "Removing:"
    for pkg in "${remove_pkgs[@]}"; do
        local version
        version="${pkg//linux-image-/}"
        echo "  $pkg"
        echo "  linux-headers-$version (if installed)"
    done
    echo

    # Dry-run: just show what would happen
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove ${#remove_pkgs[@]} kernel(s)"
        return 0
    fi

    # Prompt for confirmation unless --force
    if [[ "${FORCE:-false}" != "true" ]]; then
        printf "Remove %d old kernel(s)? [y/N] " "${#remove_pkgs[@]}"
        read -r answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            return 0
        fi
        echo
    fi

    # Remove each kernel package + matching headers
    for pkg in "${remove_pkgs[@]}"; do
        local version
        version="${pkg//linux-image-/}"
        log_info "Removing $pkg..."
        run_cmd maybe_sudo apt remove -y "$pkg" || true
        # Remove matching headers if installed
        local header_pkgs
        header_pkgs=$(dpkg --list | grep -E "^ii\s+linux-headers-${version}" | awk '{print $2}' || true)
        if [[ -n "$header_pkgs" ]]; then
            while IFS= read -r hdr; do
                [[ -z "$hdr" ]] && continue
                log_info "Removing $hdr..."
                run_cmd maybe_sudo apt remove -y "$hdr" || true
            done <<< "$header_pkgs"
        fi
    done

    # Purge rc entries
    log_info "Purging removed package configs..."
    local rc_pkgs
    rc_pkgs=$(dpkg --list | grep "^rc" | awk '{print $2}' || true)
    if [[ -n "$rc_pkgs" ]]; then
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            run_cmd maybe_sudo dpkg --purge "$pkg" || true
        done <<< "$rc_pkgs"
    fi

    # Clean up
    run_cmd maybe_sudo apt autoremove -y
    run_cmd maybe_sudo update-grub

    echo
    log_success "Kernel cleanup complete"
    echo
    log_step "Remaining kernels:"
    dpkg --list | grep -E "^ii\s+linux-image-[0-9]" | awk '{print "  " $2}'
}

###############################################################################
# Subcommand: apt
###############################################################################

cleanup_apt() {
    if [[ "$PKG_MGR" != "apt" ]]; then
        log_info "APT cleanup is only applicable on apt-based systems"
        return 0
    fi

    log_step "APT Repository Audit"
    echo

    # List all repo files
    local repo_dir="/etc/apt/sources.list.d"
    local repo_files=()
    if [[ -d "$repo_dir" ]]; then
        while IFS= read -r -d '' file; do
            repo_files+=("$file")
        done < <(find "$repo_dir" -maxdepth 1 \( -name "*.list" -o -name "*.sources" \) -print0 | sort -z)
    fi

    if [[ ${#repo_files[@]} -eq 0 ]]; then
        log_info "No third-party repository files found"
        return 0
    fi

    log_info "Found ${#repo_files[@]} repository file(s):"
    echo

    local removed=0

    for repo_file in "${repo_files[@]}"; do
        local basename_no_ext
        basename_no_ext=$(basename "$repo_file" | sed 's/\.\(list\|sources\)$//')

        echo "  $(basename "$repo_file")"

        # Try to find associated keyring files
        local keyrings=()
        for keyring_dir in /etc/apt/trusted.gpg.d /usr/share/keyrings; do
            if [[ -d "$keyring_dir" ]]; then
                while IFS= read -r -d '' keyfile; do
                    keyrings+=("$keyfile")
                done < <(find "$keyring_dir" -maxdepth 1 -name "${basename_no_ext}*" -print0 2>/dev/null)
            fi
        done

        if [[ ${#keyrings[@]} -gt 0 ]]; then
            for k in "${keyrings[@]}"; do
                echo "    keyring: $k"
            done
        fi

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "  [DRY-RUN] Would prompt for removal"
            echo
            continue
        fi

        if [[ "${FORCE:-false}" == "true" ]]; then
            log_info "  Skipping (use interactive mode without --force)"
            echo
            continue
        fi

        printf "  Remove this repository? [y/N] "
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log_info "  Removing $repo_file..."
            run_cmd maybe_sudo rm -f "$repo_file"
            for k in "${keyrings[@]}"; do
                log_info "  Removing keyring $k..."
                run_cmd maybe_sudo rm -f "$k"
            done
            removed=$((removed + 1))
        fi
        echo
    done

    if [[ $removed -gt 0 ]]; then
        log_info "Removed $removed repository file(s). Cleaning up..."
        run_cmd maybe_sudo apt update
        run_cmd maybe_sudo apt autoremove -y
        run_cmd maybe_sudo apt clean
        echo
        log_success "APT cleanup complete"
    else
        log_info "No repositories removed"
    fi
}

###############################################################################
# Main command dispatcher
###############################################################################

cmd_cleanup() {
    local subcommand="${1:-}"

    if [[ -z "$subcommand" ]]; then
        show_cleanup_help
        return 0
    fi

    shift

    case "$subcommand" in
        -h|--help)
            show_cleanup_help
            return 0
            ;;
        kernels)
            cleanup_kernels
            ;;
        apt)
            cleanup_apt
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"
            echo
            show_cleanup_help
            return 1
            ;;
    esac
}
