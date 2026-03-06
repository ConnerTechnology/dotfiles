#!/usr/bin/env bash

# Component registry for ctdev

# Get the root directory of the dotfiles
if [[ -z "$DOTFILES_ROOT" ]]; then
    DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Define available components (alphabetical)
# Format: name:description:install_script
declare -a COMPONENTS=(
    "1password:1Password password manager:components/1password/install.sh"
    "age:age file encryption tool:components/age/install.sh"
    "bleachbit:System cleaner for Linux:components/bleachbit/install.sh"
    "btop:Resource monitor (htop alternative):components/btop/install.sh"
    "bun:JavaScript runtime and package manager:components/bun/install.sh"
    "chatgpt:ChatGPT desktop application:components/chatgpt/install.sh"
    "chrome:Google Chrome browser:components/chrome/install.sh"
    "cleanmymac:CleanMyMac system cleaner:components/cleanmymac/install.sh"
    "claude-code:Claude Code CLI and configuration:components/claude-code/install.sh"
    "codex:OpenAI Codex CLI:components/codex/install.sh"
    "claude-desktop:Claude desktop application:components/claude-desktop/install.sh"
    "dbeaver:DBeaver database tool:components/dbeaver/install.sh"
    "docker:Docker container runtime:components/docker/install.sh"
    "doctl:DigitalOcean CLI:components/doctl/install.sh"
    "earlyoom:Early OOM killer for Linux:components/earlyoom/install.sh"
    "fonts:Nerd Fonts for terminal:components/fonts/install.sh"
    "gh:GitHub CLI:components/gh/install.sh"
    "ghostty:Ghostty terminal emulator:components/ghostty/install.sh"
    "git:Git configuration and aliases:components/git/install.sh"
    "git-spice:Git Spice stacked branches tool:components/git-spice/install.sh"
    "helm:Kubernetes package manager:components/helm/install.sh"
    "jq:JSON processor:components/jq/install.sh"
    "kubectl:Kubernetes CLI:components/kubectl/install.sh"
    "linear:Linear issue tracker:components/linear/install.sh"
    "logi-options:Logitech Options+:components/logi-options/install.sh"
    "node:Node.js via nodenv:components/node/install.sh"
    "ruby:Ruby via rbenv:components/ruby/install.sh"
    "shellcheck:Shell script linter:components/shellcheck/install.sh"
    "slack:Slack messaging:components/slack/install.sh"
    "solaar:Logitech Unifying/Bolt receiver manager:components/solaar/install.sh"
    "sops:Mozilla SOPS secrets manager:components/sops/install.sh"
    "tailscale:Tailscale VPN:components/tailscale/install.sh"
    "terraform:Terraform infrastructure tool:components/terraform/install.sh"
    "tmux:Terminal multiplexer:components/tmux/install.sh"
    "vscode:Visual Studio Code:components/vscode/install.sh"
    "windows-setup:Windows bloatware removal, privacy, and performance tweaks:components/windows-setup/install.sh"
    "windows-terminal:Windows Terminal configuration:components/windows-terminal/install.sh"
    "zsh:Zsh, Oh My Zsh, Pure prompt, plugins:components/zsh/install.sh"
)

# List all available components
list_components() {
    local name desc script entry
    for entry in "${COMPONENTS[@]}"; do
        IFS=':' read -r name desc script <<< "$entry"
        echo "$name"
    done
}

# Get component description
get_component_description() {
    local target="$1"
    local name desc script entry
    for entry in "${COMPONENTS[@]}"; do
        IFS=':' read -r name desc script <<< "$entry"
        if [[ "$name" == "$target" ]]; then
            echo "$desc"
            return 0
        fi
    done
    return 1
}

# Get path to component install script
get_component_install_script() {
    local target="$1"
    local name desc script entry
    for entry in "${COMPONENTS[@]}"; do
        IFS=':' read -r name desc script <<< "$entry"
        if [[ "$name" == "$target" ]]; then
            echo "${DOTFILES_ROOT}/${script}"
            return 0
        fi
    done
    return 1
}

# Check if a component name is valid
is_valid_component() {
    local target="$1"
    local name desc script entry
    for entry in "${COMPONENTS[@]}"; do
        IFS=':' read -r name desc script <<< "$entry"
        if [[ "$name" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if a component is installed
# First checks for installation marker, then falls back to heuristics
# Returns 0 if installed, 1 if not
is_component_installed() {
    local component="$1"

    # First check for installation marker (most reliable)
    if has_install_marker "$component"; then
        return 0
    fi

    # Fallback to heuristic checks (for backwards compatibility)
    case "$component" in
        # Desktop applications
        1password)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/1Password.app" ]]
            else
                command -v 1password >/dev/null 2>&1
            fi
            ;;
        chatgpt)
            [[ -d "/Applications/ChatGPT.app" ]]
            ;;
        chrome)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/Google Chrome.app" ]]
            else
                command -v google-chrome >/dev/null 2>&1
            fi
            ;;
        codex)
            command -v codex >/dev/null 2>&1 || [[ -x "$HOME/.nodenv/shims/codex" ]]
            ;;
        bleachbit)
            command -v bleachbit >/dev/null 2>&1
            ;;
        cleanmymac)
            [[ -d "/Applications/CleanMyMac.app" ]] || [[ -d "/Applications/CleanMyMac X.app" ]]
            ;;
        claude-desktop)
            [[ -d "/Applications/Claude.app" ]]
            ;;
        dbeaver)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/DBeaver.app" ]]
            else
                command -v dbeaver >/dev/null 2>&1
            fi
            ;;
        ghostty)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/Ghostty.app" ]]
            else
                command -v ghostty >/dev/null 2>&1
            fi
            ;;
        linear)
            [[ -d "/Applications/Linear.app" ]]
            ;;
        logi-options)
            [[ -d "/Applications/Logi Options+.app" ]] || [[ -d "/Applications/Logi Options.app" ]]
            ;;
        slack)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/Slack.app" ]]
            else
                command -v slack >/dev/null 2>&1
            fi
            ;;
        vscode)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code >/dev/null 2>&1
            else
                command -v code >/dev/null 2>&1
            fi
            ;;

        # CLI tools
        age)
            command -v age >/dev/null 2>&1
            ;;
        btop)
            command -v btop >/dev/null 2>&1
            ;;
        bun)
            command -v bun >/dev/null 2>&1 || [[ -x "$HOME/.bun/bin/bun" ]]
            ;;
        claude-code)
            command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]
            ;;
        docker)
            command -v docker >/dev/null 2>&1
            ;;
        doctl)
            command -v doctl >/dev/null 2>&1
            ;;
        earlyoom)
            command -v earlyoom >/dev/null 2>&1
            ;;
        gh)
            command -v gh >/dev/null 2>&1
            ;;
        git-spice)
            command -v gs >/dev/null 2>&1
            ;;
        helm)
            command -v helm >/dev/null 2>&1
            ;;
        jq)
            command -v jq >/dev/null 2>&1
            ;;
        kubectl)
            command -v kubectl >/dev/null 2>&1
            ;;
        shellcheck)
            command -v shellcheck >/dev/null 2>&1
            ;;
        solaar)
            command -v solaar >/dev/null 2>&1
            ;;
        sops)
            command -v sops >/dev/null 2>&1
            ;;
        tailscale)
            command -v tailscale >/dev/null 2>&1
            ;;
        terraform)
            command -v terraform >/dev/null 2>&1
            ;;
        tmux)
            command -v tmux >/dev/null 2>&1
            ;;

        # WSL only
        windows-setup)
            has_install_marker windows-setup
            ;;
        windows-terminal)
            is_wsl && [[ -d "$(get_windows_home)/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe" ]] 2>/dev/null
            ;;

        # Configuration
        fonts)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                ls ~/Library/Fonts/*Nerd* >/dev/null 2>&1
            else
                ls ~/.local/share/fonts/*Nerd* >/dev/null 2>&1 || ls /usr/share/fonts/*Nerd* >/dev/null 2>&1
            fi
            ;;
        git)
            [[ -L ~/.gitconfig ]] && [[ -e ~/.gitconfig ]]
            ;;
        node)
            [[ -d ~/.nodenv ]] && command -v node >/dev/null 2>&1
            ;;
        ruby)
            [[ -d ~/.rbenv ]] && command -v ruby >/dev/null 2>&1
            ;;
        zsh)
            [[ -d ~/.oh-my-zsh ]]
            ;;

        *)
            return 1
            ;;
    esac
}

# Get installation status string
get_component_status() {
    local component="$1"
    if is_component_installed "$component"; then
        echo "installed"
    else
        echo "not installed"
    fi
}

# Validate a list of components
# Returns 0 if all valid, 1 if any invalid
validate_components() {
    local invalid=()

    for comp in "$@"; do
        if ! is_valid_component "$comp"; then
            invalid+=("$comp")
        fi
    done

    if [[ ${#invalid[@]} -gt 0 ]]; then
        for inv in "${invalid[@]}"; do
            log_error "Unknown component: $inv"
        done
        echo ""
        echo "Available components:"
        list_components | while read -r name; do
            echo "  $name"
        done
        return 1
    fi

    return 0
}

# List all currently installed components
list_installed_components() {
    local name
    for name in $(list_components); do
        if is_component_installed "$name"; then
            echo "$name"
        fi
    done
}

# Check if a component is supported on the current OS
# Returns 0 if supported, 1 if not
is_component_supported() {
    local component="$1"
    local os
    os=$(uname -s)

    case "$component" in
        # macOS only
        cleanmymac|logi-options)
            [[ "$os" == "Darwin" ]]
            ;;
        # Linux only (not useful in WSL)
        bleachbit|earlyoom|solaar)
            [[ "$os" == "Linux" ]] && ! is_wsl
            ;;
        # macOS only (no Linux/Windows desktop app)
        chatgpt|linear|claude-desktop)
            [[ "$os" == "Darwin" ]]
            ;;
        # WSL only
        windows-setup|windows-terminal)
            is_wsl
            ;;
        # All other components are cross-platform
        *)
            return 0
            ;;
    esac
}
