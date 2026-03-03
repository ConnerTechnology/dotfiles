#!/usr/bin/env bash
set -euo pipefail

# Git configuration script - used by both install.sh and ctdev configure git
# Usage: configure.sh [OPTIONS]
#   --name NAME       Set git user.name
#   --email EMAIL     Set git user.email
#   --local           Configure for current repo only (not global)
#   --skip            Skip if already configured (for install)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

# Default values
GIT_USER_NAME=""
GIT_USER_EMAIL=""
SKIP_IF_CONFIGURED=false
LOCAL_CONFIG=false
SHOW_CONFIG=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            GIT_USER_NAME="$2"
            shift 2
            ;;
        --email)
            GIT_USER_EMAIL="$2"
            shift 2
            ;;
        --local)
            LOCAL_CONFIG=true
            shift
            ;;
        --skip)
            SKIP_IF_CONFIGURED=true
            shift
            ;;
        --show)
            SHOW_CONFIG=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Show current git configuration
show_git_config() {
    local global_name global_email local_name local_email
    global_name=$(git config --global user.name 2>/dev/null || echo "")
    global_email=$(git config --global user.email 2>/dev/null || echo "")

    echo ""
    log_info "Git Configuration"
    echo ""
    echo "Global:"
    if [[ -n "$global_name" || -n "$global_email" ]]; then
        echo "  user.name:  ${global_name:-<not set>}"
        echo "  user.email: ${global_email:-<not set>}"
    else
        echo "  <not configured>"
    fi

    # Show local config if in a git repo
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local_name=$(git config --local user.name 2>/dev/null || echo "")
        local_email=$(git config --local user.email 2>/dev/null || echo "")
        echo ""
        echo "Local (this repo):"
        if [[ -n "$local_name" || -n "$local_email" ]]; then
            echo "  user.name:  ${local_name:-<not set>}"
            echo "  user.email: ${local_email:-<not set>}"
        else
            echo "  <not configured>"
        fi
    fi
    echo ""
}

# Validate email format
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Get current git user configuration
get_current_git_user() {
    local scope="$1"
    local name email
    if [[ "$scope" == "local" ]]; then
        name=$(git config --local user.name 2>/dev/null || echo "")
        email=$(git config --local user.email 2>/dev/null || echo "")
    else
        name=$(git config --global user.name 2>/dev/null || echo "")
        email=$(git config --global user.email 2>/dev/null || echo "")
    fi
    echo "$name|$email"
}

# Configure git user
configure_git_user() {
    local name="$1"
    local email="$2"
    local scope="$3"

    if [[ -z "$name" ]]; then
        log_error "Git user name cannot be empty"
        return 1
    fi

    if [[ -z "$email" ]]; then
        log_error "Git user email cannot be empty"
        return 1
    fi

    if ! validate_email "$email"; then
        log_warning "Email format may be invalid: $email"
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would configure git user ($scope): $name <$email>"
        return 0
    fi

    if [[ "$scope" == "local" ]]; then
        git config --local user.name "$name"
        git config --local user.email "$email"
        log_success "Git user configured (local): $name <$email>"
    else
        git config --global user.name "$name"
        git config --global user.email "$email"
        log_success "Git user configured (global): $name <$email>"
    fi
}

# Prompt for git user info interactively
prompt_git_user() {
    local scope="$1"
    local current_name current_email
    IFS='|' read -r current_name current_email <<< "$(get_current_git_user "$scope")"

    # If local and no local config, show global as default
    if [[ "$scope" == "local" && -z "$current_name" ]]; then
        IFS='|' read -r current_name current_email <<< "$(get_current_git_user "global")"
    fi

    echo ""
    if [[ "$scope" == "local" ]]; then
        log_info "Git user configuration (local - this repo only)"
    else
        log_info "Git user configuration (global)"
    fi
    echo ""

    # Prompt for name
    if [[ -n "$current_name" ]]; then
        read -r -p "Enter your name [$current_name]: " input_name
        GIT_USER_NAME="${input_name:-$current_name}"
    else
        read -r -p "Enter your name: " GIT_USER_NAME
    fi

    # Prompt for email
    if [[ -n "$current_email" ]]; then
        read -r -p "Enter your email [$current_email]: " input_email
        GIT_USER_EMAIL="${input_email:-$current_email}"
    else
        read -r -p "Enter your email: " GIT_USER_EMAIL
    fi
}

# Handle --show flag
if [[ "$SHOW_CONFIG" == "true" ]]; then
    show_git_config
    exit 0
fi

# Determine scope
if [[ "$LOCAL_CONFIG" == "true" ]]; then
    SCOPE="local"
    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository. --local requires being in a git repo."
        exit 1
    fi
else
    SCOPE="global"
fi

# Main logic
IFS='|' read -r current_name current_email <<< "$(get_current_git_user "$SCOPE")"

# Skip if already configured and --skip was passed (only when no explicit args given)
if [[ "$SKIP_IF_CONFIGURED" == "true" && -z "$GIT_USER_NAME" && -z "$GIT_USER_EMAIL" && -n "$current_name" && -n "$current_email" ]]; then
    log_info "Git user already configured ($SCOPE): $current_name <$current_email>"
    exit 0
fi

# If name and email provided via args, use them
if [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]]; then
    configure_git_user "$GIT_USER_NAME" "$GIT_USER_EMAIL" "$SCOPE"
elif [[ -t 0 ]]; then
    # Interactive terminal - prompt for input
    prompt_git_user "$SCOPE"
    if [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]]; then
        configure_git_user "$GIT_USER_NAME" "$GIT_USER_EMAIL" "$SCOPE"
    else
        log_error "Name and email are required"
        exit 1
    fi
else
    # Non-interactive - error out
    log_error "Git user configuration requires --name and --email in non-interactive mode"
    exit 1
fi
