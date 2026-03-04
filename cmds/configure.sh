#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

# Show help for configure command
show_configure_help() {
    cat << 'EOF'
ctdev configure - Configure git settings

Usage: ctdev configure <TARGET> [OPTIONS]

Targets:
    git              Configure git user (name and email)

Git Options:
    --name NAME      Set git user.name
    --email EMAIL    Set git user.email
    --local          Configure for current repo only (not global)
    --show           Show current git configuration

General Options:
    -h, --help       Show this help message
    -n, --dry-run    Preview changes without applying

For OS configuration (macOS/Linux Mint), use 'ctdev setup'.
Use 'ctdev setup --show' to view current OS configuration.
Use 'ctdev setup --reset' to reset OS configuration to defaults.

Examples:
    ctdev configure git                       Interactive git configuration (global)
    ctdev configure git --show                Show current git configuration
    ctdev configure git --local               Configure git for current repo only
    ctdev configure git --name "Name" --email "email@example.com"
    ctdev configure git --local --name "Work Name" --email "work@example.com"
EOF
}

# Main command handler
cmd_configure() {
    local target=""
    local args=()

    # Check for help first
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_configure_help
            return 0
        fi
    done

    # Get target (first non-flag argument)
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        target="$1"
        shift
        args=("$@")
    fi

    if [[ -z "$target" ]]; then
        log_error "No target specified"
        echo ""
        echo "Usage: ctdev configure <TARGET>"
        echo ""
        echo "Targets:"
        echo "  git         Configure git user (name and email)"
        echo ""
        echo "For OS configuration, use 'ctdev setup'."
        echo "Run 'ctdev configure --help' for more information."
        return 1
    fi

    case "$target" in
        git)
            configure_git ${args[@]+"${args[@]}"}
            ;;
        macos|linux-mint)
            log_info "OS configuration has moved to 'ctdev setup'."
            log_info "Run 'ctdev setup' or 'ctdev setup --show'."
            return 0
            ;;
        *)
            log_error "Unknown target: $target"
            echo ""
            echo "Valid targets: git"
            echo "For OS configuration, use 'ctdev setup'."
            return 1
            ;;
    esac
}

# Configure git
configure_git() {
    local configure_script="$DOTFILES_ROOT/components/git/configure.sh"

    if [[ ! -f "$configure_script" ]]; then
        log_error "Git component not found. Run 'ctdev components install git' first."
        return 1
    fi

    bash "$configure_script" "$@"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd_configure "$@"
fi
