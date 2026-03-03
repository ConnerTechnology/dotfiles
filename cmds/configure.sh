#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$DOTFILES_ROOT/lib/utils.sh"

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
    ctdev configure git --local --name "Work Name" --email "work@example.com"
    ctdev configure macos                     Apply macOS preferences
    ctdev configure macos --show              Show current macOS configuration
    ctdev configure macos --reset             Reset to Apple defaults
    ctdev configure linux-mint                Apply Linux Mint preferences
    ctdev configure linux-mint --show         Show current Linux Mint configuration
    ctdev configure linux-mint --reset        Reset to Cinnamon defaults
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
        echo "  macos       Configure macOS system defaults"
        echo "  linux-mint  Configure Linux Mint system defaults"
        echo ""
        echo "Run 'ctdev configure --help' for more information."
        return 1
    fi

    case "$target" in
        git)
            configure_git ${args[@]+"${args[@]}"}
            ;;
        macos)
            configure_macos ${args[@]+"${args[@]}"}
            ;;
        linux-mint)
            configure_linux_mint ${args[@]+"${args[@]}"}
            ;;
        *)
            log_error "Unknown target: $target"
            echo ""
            echo "Valid targets: git, macos, linux-mint"
            return 1
            ;;
    esac
}

# Configure git
configure_git() {
    local configure_script="$DOTFILES_ROOT/components/git/configure.sh"

    if [[ ! -f "$configure_script" ]]; then
        log_error "Git component not found. Run 'ctdev install git' first."
        return 1
    fi

    bash "$configure_script" "$@"
}

# Configure macOS
configure_macos() {
    local reset_mode=false
    local show_mode=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --reset)
                reset_mode=true
                ;;
            --show)
                show_mode=true
                ;;
            -*)
                # Ignore other flags (handled by main dispatcher)
                ;;
            *)
                log_error "Unknown option: $arg"
                echo ""
                echo "Usage: ctdev configure macos [--show] [--reset] [--dry-run]"
                return 1
                ;;
        esac
    done

    # Only run on macOS
    if [[ "$(detect_os)" != "macos" ]]; then
        log_error "This command is only available on macOS"
        return 1
    fi

    if [[ "$show_mode" == "true" ]]; then
        macos_show
    elif [[ "$reset_mode" == "true" ]]; then
        macos_reset
    else
        macos_apply
    fi
}

macos_show() {
    echo ""
    log_info "macOS Configuration"
    echo ""

    format_macos_bool() {
        case "$1" in
            1|true) echo "yes" ;;
            0|false) echo "no" ;;
            *) echo "$1" ;;
        esac
    }

    format_seconds() {
        local val="$1"
        if [[ "$val" == "<system default>" ]]; then
            echo "$val"
            return
        fi
        if ! [[ "$val" =~ ^[0-9]+$ ]]; then
            echo "$val"
            return
        fi
        if (( val >= 3600 && val % 3600 == 0 )); then
            echo "$(( val / 3600 )) hr"
        elif (( val >= 60 && val % 60 == 0 )); then
            echo "$(( val / 60 )) min"
        elif (( val >= 60 )); then
            echo "$(( val / 60 )) min $(( val % 60 )) sec"
        else
            echo "${val} sec"
        fi
    }

    format_search_scope() {
        case "$1" in
            SCcf) echo "current folder" ;;
            SCsp) echo "previous scope" ;;
            SCev) echo "this Mac" ;;
            *) echo "$1" ;;
        esac
    }

    format_view_style() {
        case "$1" in
            Nlsv) echo "list" ;;
            icnv) echo "icon" ;;
            clmv) echo "column" ;;
            glyv) echo "gallery" ;;
            *) echo "$1" ;;
        esac
    }

    # show_default DOMAIN KEY LABEL [FORMAT]
    # FORMAT: raw (default), bool, seconds, float_seconds, search_scope, view_style
    show_default() {
        local domain="$1"
        local key="$2"
        local label="$3"
        local format="${4:-raw}"
        local value
        value=$(defaults read "$domain" "$key" 2>/dev/null || echo "<system default>")
        case "$format" in
            bool) value=$(format_macos_bool "$value") ;;
            seconds) value=$(format_seconds "$value") ;;
            float_seconds)
                [[ "$value" != "<system default>" ]] && value="${value} sec"
                ;;
            search_scope) value=$(format_search_scope "$value") ;;
            view_style) value=$(format_view_style "$value") ;;
        esac
        printf "  %-40s %s\n" "$label:" "$value"
    }

    echo "Dock:"
    show_default "com.apple.dock" "autohide" "Auto-hide" bool
    show_default "com.apple.dock" "launchanim" "Launch animation" bool
    show_default "com.apple.dock" "show-recents" "Show recent apps" bool
    echo ""

    echo "Sound:"
    show_default "NSGlobalDomain" "com.apple.sound.beep.feedback" "Volume change feedback" bool
    echo ""

    echo "Finder:"
    show_default "com.apple.finder" "ShowPathbar" "Show path bar" bool
    show_default "com.apple.finder" "ShowStatusBar" "Show status bar" bool
    show_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "No .DS_Store on network" bool
    show_default "com.apple.desktopservices" "DSDontWriteUSBStores" "No .DS_Store on USB" bool
    show_default "com.apple.finder" "FXDefaultSearchScope" "Default search scope" search_scope
    show_default "com.apple.finder" "FXPreferredViewStyle" "Preferred view style" view_style
    show_default "com.apple.finder" "QuitMenuItem" "Allow quit" bool
    echo ""

    echo "Keyboard:"
    show_default "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "Smart quotes" bool
    show_default "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "Smart dashes" bool
    show_default "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "Auto-correct" bool
    show_default "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "Auto-capitalize" bool
    show_default "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "Double-space period" bool
    show_default "NSGlobalDomain" "KeyRepeat" "Key repeat rate"
    show_default "NSGlobalDomain" "InitialKeyRepeat" "Initial key repeat delay"
    echo ""

    echo "Dialogs:"
    show_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode" "Expand save dialogs" bool
    show_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode2" "Expand save dialogs 2" bool
    show_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint" "Expand print dialogs" bool
    show_default "NSGlobalDomain" "PMPrintingExpandedStateForPrint2" "Expand print dialogs 2" bool
    echo ""

    echo "Security:"
    show_default "com.apple.screensaver" "askForPassword" "Require password" bool
    show_default "com.apple.screensaver" "askForPasswordDelay" "Password delay" seconds
    echo ""
}

macos_apply() {
    log_step "Configuring macOS System Defaults"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would configure Dock settings (auto-hide, animations, recent apps)"
        log_info "[DRY-RUN] Would configure Sound settings (volume change feedback)"
        log_info "[DRY-RUN] Would configure Finder settings (path bar, status bar)"
        log_info "[DRY-RUN] Would configure Keyboard settings (disable smart quotes/dashes)"
        log_info "[DRY-RUN] Would configure Dialog settings (expand save/print dialogs)"
        log_info "[DRY-RUN] Would configure Security settings (require password after sleep)"
        log_info "[DRY-RUN] Would restart Dock and Finder"
        log_success "macOS defaults would be configured"
        return 0
    fi

    # Dock Settings
    log_info "Configuring Dock..."
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock show-recents -bool false

    # Sound Settings
    log_info "Configuring Sound..."
    defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool true

    # Finder Settings
    log_info "Configuring Finder..."
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write com.apple.finder QuitMenuItem -bool true

    # Keyboard Settings
    log_info "Configuring Keyboard..."
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15

    # Dialog Settings
    log_info "Configuring Dialogs..."
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

    # Security Settings
    log_info "Configuring Security..."
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    # Apply changes
    log_info "Applying changes..."
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true

    log_success "macOS defaults configured"
    log_info "Some settings may require logout/restart to take full effect"
}

macos_reset() {
    log_step "Resetting macOS System Defaults"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would reset Dock, Finder, Keyboard, Dialog, Security settings"
        log_info "[DRY-RUN] Would restart Dock and Finder"
        log_success "macOS defaults would be reset"
        return 0
    fi

    log_info "Resetting Dock settings..."
    defaults delete com.apple.dock autohide 2>/dev/null || true
    defaults delete com.apple.dock launchanim 2>/dev/null || true
    defaults delete com.apple.dock show-recents 2>/dev/null || true

    log_info "Resetting Sound settings..."
    defaults delete NSGlobalDomain com.apple.sound.beep.feedback 2>/dev/null || true

    log_info "Resetting Finder settings..."
    defaults delete com.apple.finder AppleShowAllFiles 2>/dev/null || true
    defaults delete com.apple.finder ShowPathbar 2>/dev/null || true
    defaults delete com.apple.finder ShowStatusBar 2>/dev/null || true
    defaults delete com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null || true
    defaults delete com.apple.desktopservices DSDontWriteUSBStores 2>/dev/null || true
    defaults delete com.apple.finder FXDefaultSearchScope 2>/dev/null || true
    defaults delete com.apple.finder FXPreferredViewStyle 2>/dev/null || true
    defaults delete com.apple.finder QuitMenuItem 2>/dev/null || true

    log_info "Resetting Keyboard settings..."
    defaults delete NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSAutomaticDashSubstitutionEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSAutomaticSpellingCorrectionEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSAutomaticCapitalizationEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled 2>/dev/null || true
    defaults delete NSGlobalDomain KeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain InitialKeyRepeat 2>/dev/null || true
    defaults delete NSGlobalDomain AppleKeyboardUIMode 2>/dev/null || true

    log_info "Resetting Dialog settings..."
    defaults delete NSGlobalDomain NSNavPanelExpandedStateForSaveMode 2>/dev/null || true
    defaults delete NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 2>/dev/null || true
    defaults delete NSGlobalDomain PMPrintingExpandedStateForPrint 2>/dev/null || true
    defaults delete NSGlobalDomain PMPrintingExpandedStateForPrint2 2>/dev/null || true

    log_info "Resetting Security settings..."
    defaults delete com.apple.screensaver askForPassword 2>/dev/null || true
    defaults delete com.apple.screensaver askForPasswordDelay 2>/dev/null || true

    # Apply changes
    log_info "Applying changes..."
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true

    log_success "macOS defaults reset to system defaults"
    log_info "Some settings may require logout/restart to take full effect"
}

# Configure Linux Mint
configure_linux_mint() {
    local reset_mode=false
    local show_mode=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --reset)
                reset_mode=true
                ;;
            --show)
                show_mode=true
                ;;
            -*)
                # Ignore other flags (handled by main dispatcher)
                ;;
            *)
                log_error "Unknown option: $arg"
                echo ""
                echo "Usage: ctdev configure linux-mint [--show] [--reset] [--dry-run]"
                return 1
                ;;
        esac
    done

    # Only run on Linux Mint
    if [[ "$(detect_os)" != "linuxmint" ]]; then
        log_error "This command is only available on Linux Mint"
        return 1
    fi

    if [[ "$show_mode" == "true" ]]; then
        linux_mint_show
    elif [[ "$reset_mode" == "true" ]]; then
        linux_mint_reset
    else
        linux_mint_apply
    fi
}

linux_mint_show() {
    echo ""
    log_info "Linux Mint Configuration"
    echo ""

    # Strip type prefixes (uint32, int32) and surrounding quotes from raw values
    clean_value() {
        local val="$1"
        val="${val#uint32 }"
        val="${val#int32 }"
        val="${val#int64 }"
        val="${val#\'}"
        val="${val%\'}"
        echo "$val"
    }

    format_bool() {
        local val
        val=$(clean_value "$1")
        case "$val" in
            true) echo "yes" ;;
            false) echo "no" ;;
            *) echo "$val" ;;
        esac
    }

    format_seconds() {
        local val
        val=$(clean_value "$1")
        if [[ "$val" == "<system default>" || "$val" == "<unavailable>" ]]; then
            echo "$val"
            return
        fi
        if ! [[ "$val" =~ ^[0-9]+$ ]]; then
            echo "$val"
            return
        fi
        if (( val >= 3600 && val % 3600 == 0 )); then
            echo "$(( val / 3600 )) hr"
        elif (( val >= 60 && val % 60 == 0 )); then
            echo "$(( val / 60 )) min"
        elif (( val >= 60 )); then
            echo "$(( val / 60 )) min $(( val % 60 )) sec"
        else
            echo "${val} sec"
        fi
    }

    # show_dconf KEY LABEL [FORMAT]
    # FORMAT: raw (default), bool, seconds, ms, speed
    show_dconf() {
        local key="$1"
        local label="$2"
        local format="${3:-raw}"
        local value
        value=$(dconf read "$key" 2>/dev/null || echo "<system default>")
        [[ -z "$value" ]] && value="<system default>"
        case "$format" in
            bool) value=$(format_bool "$value") ;;
            seconds) value=$(format_seconds "$value") ;;
            ms)
                value=$(clean_value "$value")
                [[ "$value" != "<system default>" ]] && value="${value} ms"
                ;;
            speed)
                value=$(clean_value "$value")
                if [[ "$value" != "<system default>" ]]; then
                    value=$(awk "BEGIN { printf \"%.0f%%\", $value * 100 }")
                fi
                ;;
            *) value=$(clean_value "$value") ;;
        esac
        printf "  %-40s %s\n" "$label:" "$value"
    }

    show_gsetting() {
        local schema="$1"
        local key="$2"
        local label="$3"
        local format="${4:-raw}"
        local value
        value=$(gsettings get "$schema" "$key" 2>/dev/null || echo "<system default>")
        case "$format" in
            bool) value=$(format_bool "$value") ;;
            seconds) value=$(format_seconds "$value") ;;
            ms)
                value=$(clean_value "$value")
                [[ "$value" != "<system default>" ]] && value="${value} ms"
                ;;
            *) value=$(clean_value "$value") ;;
        esac
        printf "  %-40s %s\n" "$label:" "$value"
    }

    echo "Power:"
    local profile
    profile=$(powerprofilesctl get 2>/dev/null || echo "<unavailable>")
    printf "  %-40s %s\n" "Power profile:" "$profile"
    show_dconf "/org/cinnamon/settings-daemon/plugins/power/sleep-display-ac" "Display sleep on AC" seconds
    show_dconf "/org/cinnamon/settings-daemon/plugins/power/sleep-inactive-ac-timeout" "Inactive sleep on AC" seconds
    show_dconf "/org/cinnamon/settings-daemon/plugins/power/lock-on-suspend" "Lock on suspend" bool
    echo ""

    echo "Screensaver:"
    show_dconf "/org/cinnamon/desktop/session/idle-delay" "Idle delay" seconds
    show_dconf "/org/cinnamon/desktop/screensaver/lock-enabled" "Lock enabled" bool
    show_dconf "/org/cinnamon/desktop/screensaver/lock-delay" "Lock delay" seconds
    echo ""

    echo "Keyboard:"
    show_gsetting "org.cinnamon.desktop.peripherals.keyboard" "repeat" "Key repeat" bool
    show_gsetting "org.cinnamon.desktop.peripherals.keyboard" "delay" "Repeat delay" ms
    show_gsetting "org.cinnamon.desktop.peripherals.keyboard" "repeat-interval" "Repeat interval" ms
    show_gsetting "org.cinnamon.desktop.peripherals.keyboard" "numlock-state" "Numlock state" bool
    echo ""

    echo "Mouse:"
    show_dconf "/org/cinnamon/desktop/peripherals/mouse/accel-profile" "Acceleration profile"
    show_dconf "/org/cinnamon/desktop/peripherals/mouse/speed" "Speed" speed
    show_dconf "/org/cinnamon/desktop/peripherals/mouse/natural-scroll" "Natural scroll" bool
    echo ""

    echo "Sound:"
    show_dconf "/org/cinnamon/desktop/sound/event-sounds" "Event sounds" bool
    echo ""

    echo "Nemo (File Manager):"
    show_dconf "/org/nemo/preferences/default-folder-viewer" "Default view"
    echo ""

    echo "Swap:"
    local swap_total
    swap_total=$(swapon --show --noheadings --bytes 2>/dev/null | awk '{sum+=$3} END {if(sum>0) printf "%.1f GB", sum/1073741824; else print "none"}')
    printf "  %-40s %s\n" "Total swap:" "$swap_total"
    if [[ -f /swapfile ]]; then
        local swapfile_size
        swapfile_size=$(stat -c%s /swapfile 2>/dev/null | awk '{printf "%.0f GB", $1/1073741824}')
        printf "  %-40s %s\n" "Swap file (/swapfile):" "$swapfile_size"
    else
        printf "  %-40s %s\n" "Swap file (/swapfile):" "not configured"
    fi
    if grep -q '/swapfile' /etc/fstab 2>/dev/null; then
        printf "  %-40s %s\n" "Swap file in fstab:" "yes"
    else
        printf "  %-40s %s\n" "Swap file in fstab:" "no"
    fi
    echo ""

    if lsmod | grep -q "^nvidia "; then
        echo "NVIDIA Suspend:"
        local cmdline
        cmdline=$(cat /proc/cmdline 2>/dev/null || echo "")
        if echo "$cmdline" | grep -q "NVreg_PreserveVideoMemoryAllocations=1"; then
            printf "  %-40s %s\n" "PreserveVideoMemoryAllocations:" "enabled"
        else
            printf "  %-40s %s\n" "PreserveVideoMemoryAllocations:" "not set"
        fi
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate; do
            local state
            state=$(systemctl is-enabled "${svc}.service" 2>/dev/null || echo "not found")
            printf "  %-40s %s\n" "${svc}.service:" "$state"
        done
        echo ""
    fi
}

linux_mint_apply() {
    log_step "Configuring Linux Mint System Defaults"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would configure Power settings (performance profile, sleep timers)"
        log_info "[DRY-RUN] Would configure Screensaver settings (idle delay, lock)"
        log_info "[DRY-RUN] Would configure Keyboard settings (repeat rate, numlock)"
        log_info "[DRY-RUN] Would configure Mouse settings (acceleration, speed, natural scroll)"
        log_info "[DRY-RUN] Would configure Sound settings (disable event sounds)"
        log_info "[DRY-RUN] Would configure Nemo settings (list view)"
        log_info "[DRY-RUN] Would create 8GB swap file at /swapfile"
        if lsmod | grep -q "^nvidia "; then
            log_info "[DRY-RUN] Would configure NVIDIA suspend (GRUB parameter, systemd services)"
        fi
        log_success "Linux Mint defaults would be configured"
        return 0
    fi

    # Power Settings
    log_info "Configuring Power..."
    powerprofilesctl set performance
    dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-display-ac 3600
    dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-inactive-ac-timeout 2700
    dconf write /org/cinnamon/settings-daemon/plugins/power/lock-on-suspend true

    # Screensaver Settings
    log_info "Configuring Screensaver..."
    dconf write /org/cinnamon/desktop/session/idle-delay "uint32 1800"
    dconf write /org/cinnamon/desktop/screensaver/lock-enabled false
    dconf write /org/cinnamon/desktop/screensaver/lock-delay "uint32 2"

    # Keyboard Settings
    log_info "Configuring Keyboard..."
    gsettings set org.cinnamon.desktop.peripherals.keyboard repeat true
    gsettings set org.cinnamon.desktop.peripherals.keyboard delay 500
    gsettings set org.cinnamon.desktop.peripherals.keyboard repeat-interval 30
    gsettings set org.cinnamon.desktop.peripherals.keyboard numlock-state true

    # Mouse Settings
    log_info "Configuring Mouse..."
    dconf write /org/cinnamon/desktop/peripherals/mouse/accel-profile "'flat'"
    dconf write /org/cinnamon/desktop/peripherals/mouse/speed 0.65126050420168058
    dconf write /org/cinnamon/desktop/peripherals/mouse/natural-scroll true

    # Sound Settings
    log_info "Configuring Sound..."
    dconf write /org/cinnamon/desktop/sound/event-sounds false

    # Nemo Settings
    log_info "Configuring Nemo..."
    dconf write /org/nemo/preferences/default-folder-viewer "'list-view'"

    # Swap file - add a 8GB swap file for extra headroom
    log_info "Configuring swap..."
    if [[ ! -f /swapfile ]]; then
        log_info "Creating 8GB swap file..."
        maybe_sudo fallocate -l 8G /swapfile
        maybe_sudo chmod 600 /swapfile
        maybe_sudo mkswap /swapfile
        maybe_sudo swapon /swapfile
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' | maybe_sudo tee -a /etc/fstab >/dev/null
        fi
        log_success "8GB swap file created and activated"
    else
        log_info "Swap file already exists"
        if ! swapon --show | grep -q '/swapfile'; then
            maybe_sudo swapon /swapfile
        fi
    fi

    # NVIDIA Suspend Stability (only if NVIDIA driver is loaded)
    if lsmod | grep -q "^nvidia "; then
        log_info "Configuring NVIDIA suspend stability..."

        # Add PreserveVideoMemoryAllocations kernel parameter to GRUB
        local grub_file="/etc/default/grub"
        local nvidia_param="nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        if [[ -f "$grub_file" ]] && ! grep -q "$nvidia_param" "$grub_file"; then
            log_info "Adding $nvidia_param to GRUB..."
            maybe_sudo sed -i "s/\\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\\)\"/\\1 ${nvidia_param}\"/" "$grub_file"
            maybe_sudo update-grub
        else
            log_info "NVIDIA GRUB parameter already configured"
        fi

        # Enable NVIDIA suspend/resume/hibernate services
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate; do
            if systemctl list-unit-files "${svc}.service" &>/dev/null; then
                maybe_sudo systemctl enable "${svc}.service" 2>/dev/null || true
            fi
        done
        log_success "NVIDIA suspend stability configured"
    fi

    log_success "Linux Mint defaults configured"
    log_info "Some settings may require logout/restart to take full effect"

    # Hint about manual steps that can't be automated
    if lsmod | grep -q "^amdgpu "; then
        log_warning "amdgpu module is loaded — if you have a dual-GPU system (Ryzen iGPU + NVIDIA),"
        log_warning "consider disabling the iGPU in BIOS to prevent suspend/freeze issues."
        log_warning "See: TROUBLESHOOTING.md → Linux → Desktop Freezes"
    fi
}

linux_mint_reset() {
    log_step "Resetting Linux Mint System Defaults"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would reset Power, Screensaver, Keyboard, Mouse, Sound, Nemo, Swap settings"
        if lsmod | grep -q "^nvidia "; then
            log_info "[DRY-RUN] Would reset NVIDIA suspend settings (GRUB parameter, systemd services)"
        fi
        log_success "Linux Mint defaults would be reset"
        return 0
    fi

    log_info "Resetting Power settings..."
    powerprofilesctl set balanced
    dconf reset /org/cinnamon/settings-daemon/plugins/power/sleep-display-ac
    dconf reset /org/cinnamon/settings-daemon/plugins/power/sleep-inactive-ac-timeout
    dconf reset /org/cinnamon/settings-daemon/plugins/power/lock-on-suspend

    log_info "Resetting Screensaver settings..."
    dconf reset /org/cinnamon/desktop/session/idle-delay
    dconf reset /org/cinnamon/desktop/screensaver/lock-enabled
    dconf reset /org/cinnamon/desktop/screensaver/lock-delay

    log_info "Resetting Keyboard settings..."
    gsettings reset org.cinnamon.desktop.peripherals.keyboard repeat
    gsettings reset org.cinnamon.desktop.peripherals.keyboard delay
    gsettings reset org.cinnamon.desktop.peripherals.keyboard repeat-interval
    gsettings reset org.cinnamon.desktop.peripherals.keyboard numlock-state

    log_info "Resetting Mouse settings..."
    dconf reset /org/cinnamon/desktop/peripherals/mouse/accel-profile
    dconf reset /org/cinnamon/desktop/peripherals/mouse/speed
    dconf reset /org/cinnamon/desktop/peripherals/mouse/natural-scroll

    log_info "Resetting Sound settings..."
    dconf reset /org/cinnamon/desktop/sound/event-sounds

    log_info "Resetting Nemo settings..."
    dconf reset /org/nemo/preferences/default-folder-viewer

    log_info "Resetting Swap settings..."
    if swapon --show | grep -q '/swapfile'; then
        maybe_sudo swapoff /swapfile || true
    fi
    if [[ -f /swapfile ]]; then
        maybe_sudo rm /swapfile
    fi
    if grep -q '/swapfile' /etc/fstab 2>/dev/null; then
        maybe_sudo sed -i '\|/swapfile|d' /etc/fstab
    fi

    if lsmod | grep -q "^nvidia "; then
        log_info "Resetting NVIDIA suspend settings..."
        local grub_file="/etc/default/grub"
        local nvidia_param="nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        if [[ -f "$grub_file" ]] && grep -q "$nvidia_param" "$grub_file"; then
            maybe_sudo sed -i "s/ ${nvidia_param}//" "$grub_file"
            maybe_sudo update-grub
        fi
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate; do
            maybe_sudo systemctl disable "${svc}.service" 2>/dev/null || true
        done
    fi

    log_success "Linux Mint defaults reset to system defaults"
    log_info "Some settings may require logout/restart to take full effect"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd_configure "$@"
fi
