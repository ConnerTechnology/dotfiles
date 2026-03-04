#!/usr/bin/env bash

# CLI parsing utilities for ctdev

# Get the root directory of the dotfiles
get_dotfiles_root() {
    local script_path="${BASH_SOURCE[0]}"
    cd "$(dirname "$script_path")/.." && pwd
}

DOTFILES_ROOT="$(get_dotfiles_root)"

# Get version from VERSION file
get_version() {
    local version_file="${DOTFILES_ROOT}/VERSION"
    if [[ -f "$version_file" ]]; then
        cat "$version_file"
    else
        echo "dev"
    fi
}

# Show version
show_version() {
    echo "ctdev v$(get_version)"
}

# Show main help
show_main_help() {
    cat << 'EOF'
ctdev - Conner Technology Dev CLI

Usage: ctdev [OPTIONS] COMMAND [ARGS]

Commands:
    install <component...>    Install specific components
    uninstall <component...>  Remove specific components
    update [OPTIONS]          Update system packages and components
    list                      List components with status
    info                      Show system information
    configure <target>        Configure git, macos, or linux-mint settings
    gpu <subcommand>          Manage GPU drivers and Secure Boot signing
    setup                     Set up a fresh system (runs all steps)
    cleanup <subcommand>      Clean up kernels and APT repos

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying
    -f, --force      Force re-run install scripts
    --version        Show version information

Examples:
    ctdev install zsh git                Install specific components
    ctdev list                           Show all components with status
    ctdev update                         Update installed components
    ctdev update -y                      Update without prompting
    ctdev update --check                 List available updates
    ctdev update --refresh-keys          Refresh APT keys before updating
    ctdev configure git                  Configure git user
    ctdev configure macos                Configure macOS settings
    ctdev configure linux-mint           Configure Linux Mint settings
    ctdev setup                          Run full fresh-install setup
    ctdev cleanup kernels                Remove old kernel versions

For help on a specific command:
    ctdev COMMAND --help
EOF
}

# Show help for install command
show_install_help() {
    cat << 'EOF'
ctdev install - Install specific components

Usage: ctdev install <COMPONENT...>

Installs one or more components. At least one component must be specified.

Use 'ctdev list' to see available components.

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying
    -f, --force      Re-run install scripts even if already installed

Examples:
    ctdev install zsh          Install zsh configuration
    ctdev install node ruby    Install multiple components
    ctdev install --dry-run jq Preview installation

To update installed components, use 'ctdev update'.
EOF
}

# Show help for uninstall command
show_uninstall_help() {
    cat << 'EOF'
ctdev uninstall - Remove specific components

Usage: ctdev uninstall <COMPONENT...>

Removes one or more installed components. At least one component must be specified.

Use 'ctdev list' to see installed components.

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying

Examples:
    ctdev uninstall ruby       Remove Ruby/rbenv
    ctdev uninstall node ruby  Remove multiple components
    ctdev uninstall --dry-run jq Preview removal
EOF
}

# Show help for update command
show_update_help() {
    cat << 'EOF'
ctdev update - Update system packages and components

Usage: ctdev update [OPTIONS]

Updates system packages and installed components to latest versions.

Update sources:
    - System packages (apt/brew/dnf/pacman)
    - macOS software updates (macOS only)
    - Flatpak packages (if installed)
    - Component repos: zsh, node, ruby (git pull)
    - Bun (if installed)
    - NVIDIA module re-signing (Linux, Secure Boot)

Options:
    -h, --help                       Show this help message
    -y, --yes                        Skip confirmation prompt
    -v, --verbose                    Enable verbose output
    -n, --dry-run                    Preview changes without applying
    --check                          List available updates without installing
    --refresh-keys [COMPONENT...]    Refresh APT GPG keys before updating

Examples:
    ctdev update                         Update all (with confirmation)
    ctdev update -y                      Update all without prompting
    ctdev update --check                 List available updates
    ctdev update --dry-run               Preview what would be updated
    ctdev update --refresh-keys          Refresh all APT keys, then update
    ctdev update --refresh-keys docker   Refresh only docker keys, then update
EOF
}

# Show help for list command
show_list_help() {
    cat << 'EOF'
ctdev list - List available components with status

Usage: ctdev list [OPTIONS]

Shows all components with their installation status:
- Green: installed
- Yellow: installed (update available)
- Grey: not installed

Options:
    -h, --help       Show this help message
EOF
}

# Show help for info command
show_info_help() {
    cat << 'EOF'
ctdev info - Show system information

Usage: ctdev info [OPTIONS]

Displays system information:
- OS and version
- Architecture
- Package manager
- Shell
- Dotfiles location

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
EOF
}

# Show help for configure command
show_configure_help() {
    cat << 'EOF'
ctdev configure - Configure components

Usage: ctdev configure <TARGET> [OPTIONS]

Targets:
    git              Configure git user (name and email)
    macos            Configure macOS system defaults
    linux-mint       Configure Linux Mint system defaults

Git Options:
    --name NAME      Set git user.name
    --email EMAIL    Set git user.email
    --local          Configure for current repo only (not global)
    --show           Show current git configuration

macOS Options:
    --reset          Reset to macOS system defaults
    --show           Show current macOS configuration

Linux Mint Options:
    --reset          Reset to Cinnamon system defaults
    --show           Show current Linux Mint configuration

General Options:
    -h, --help       Show this help message
    -n, --dry-run    Preview changes without applying

Examples:
    ctdev configure git                       Interactive git configuration (global)
    ctdev configure git --show                Show current git configuration
    ctdev configure git --local               Configure git for current repo only
    ctdev configure git --name "Name" --email "email@example.com"
    ctdev configure macos                     Apply macOS preferences
    ctdev configure macos --show              Show current macOS configuration
    ctdev configure macos --reset             Reset to Apple defaults
    ctdev configure linux-mint                Apply Linux Mint preferences
    ctdev configure linux-mint --show         Show current Linux Mint configuration
    ctdev configure linux-mint --reset        Reset to Cinnamon defaults
EOF
}

# Show help for gpu command
show_gpu_help() {
    cat << 'EOF'
ctdev gpu - Manage GPU drivers and Secure Boot signing

Usage: ctdev gpu <subcommand> [OPTIONS]

Subcommands:
    info      Show GPU hardware info and signing status
    setup     Configure MOK signing for NVIDIA drivers

Options:
    -h, --help       Show this help message
    -v, --verbose    Enable verbose output
    -n, --dry-run    Preview changes without applying
    -f, --force      Force re-run setup even if already configured
    --recover        Re-enroll MOK key after CMOS reset (use with setup)

Examples:
    ctdev gpu info                Show GPU info and signing status
    ctdev gpu setup               Set up MOK signing (interactive)
    ctdev gpu setup --recover     Re-enroll key after CMOS/firmware reset
    ctdev gpu setup --force       Re-run full setup even if configured
EOF
}

# Show help for setup command
show_setup_help() {
    cat << 'EOF'
ctdev setup - Set up a fresh system

Usage: ctdev setup [OPTIONS]

Runs all setup steps in the correct order for the current OS.

Options:
    -h, --help           Show this help message
    -n, --dry-run        Preview changes without applying
    --skip-update        Skip system update step
    --skip-gpu           Skip GPU setup step
    --skip-configure     Skip system configuration step
    --skip-cleanup       Skip cleanup steps

Run 'ctdev setup --help' for full details.
EOF
}

# Show help for cleanup command
show_cleanup_help() {
    cat << 'EOF'
ctdev cleanup - Clean up system resources

Usage: ctdev cleanup <subcommand> [OPTIONS]

Subcommands:
    kernels   Remove old kernel versions
    apt       Audit and clean APT repositories

Run 'ctdev cleanup --help' for full details.
EOF
}

# Parse global flags and set environment variables
# Returns the remaining arguments after flags are consumed
# Usage: eval "$(parse_global_flags "$@")"
parse_global_flags() {
    local args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo "SHOW_HELP=true"
                shift
                ;;
            -v|--verbose)
                echo "VERBOSE=true"
                echo "export VERBOSE"
                shift
                ;;
            -n|--dry-run)
                echo "DRY_RUN=true"
                echo "export DRY_RUN"
                shift
                ;;
            -f|--force)
                echo "FORCE=true"
                echo "export FORCE"
                shift
                ;;
            --version)
                echo "SHOW_VERSION=true"
                shift
                ;;
            -*)
                # Unknown flag - pass it through
                args+=("$1")
                shift
                ;;
            *)
                # Not a flag - pass it through and continue processing
                args+=("$1")
                shift
                ;;
        esac
    done

    # Output remaining args as a properly escaped array
    # Use declare -a to handle empty arrays safely with set -u
    if [[ ${#args[@]} -gt 0 ]]; then
        printf 'declare -a REMAINING_ARGS=('
        printf '%q ' "${args[@]}"
        printf ')\n'
    else
        echo 'declare -a REMAINING_ARGS=()'
    fi
}

# Validate that a command exists
require_command() {
    local cmd="$1"
    local valid_commands="install uninstall update list info configure gpu setup cleanup"

    if [[ -z "$cmd" ]]; then
        return 1
    fi

    for valid in $valid_commands; do
        if [[ "$cmd" == "$valid" ]]; then
            return 0
        fi
    done

    return 1
}
