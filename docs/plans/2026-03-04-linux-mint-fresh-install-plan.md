# Linux Mint Fresh Install Setup — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend ctdev CLI with `setup` and `cleanup` commands, expanded GRUB/services config, and merged `gpu info` subcommand for comprehensive fresh-install orchestration on Linux Mint and macOS.

**Architecture:** All new logic lives inside the existing ctdev command framework (`cmds/`, `lib/`). New commands `setup` and `cleanup` are registered in `lib/cli.sh` and dispatched from `ctdev`. Existing `configure linux-mint` is expanded in-place. No standalone scripts or new lib files.

**Tech Stack:** Bash, dpkg, apt, systemctl, GRUB, dconf/gsettings (existing patterns)

**Design doc:** `docs/plans/2026-03-04-linux-mint-fresh-install-design.md`

---

### Task 1: Merge `gpu status` into `gpu info`

**Files:**
- Modify: `cmds/gpu.sh` (entire file — rename function, add hardware info section, update dispatcher)
- Modify: `lib/cli.sh:233-256` (update `show_gpu_help`)

**Step 1: Rename `gpu_status` → `gpu_info` in `cmds/gpu.sh`**

Rename the function `gpu_status` to `gpu_info`. At the top of `gpu_info` (before the Secure Boot checks), add a hardware info section that calls `show_gpu_hardware_info` (already exists in `lib/gpu.sh`):

```bash
gpu_info() {
    log_step "GPU Information"
    echo

    # Hardware info (works on all platforms)
    show_gpu_hardware_info "  "
    echo

    # macOS doesn't use Secure Boot/MOK signing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        return 0
    fi

    log_step "Secure Boot Signing Status"

    # ... rest of existing gpu_status logic (checks 1-6) unchanged ...
```

Remove the macOS early-return that called `show_gpu_hardware_info` separately — it's now handled uniformly above.

**Step 2: Update the dispatcher in `cmd_gpu`**

In the `case` block of `cmd_gpu`, change:
- `status)` → calls `gpu_info` (alias for backwards compat)
- Add `info)` → calls `gpu_info`

```bash
case "$subcommand" in
    -h|--help)
        show_gpu_help
        return 0
        ;;
    info|status)
        gpu_info
        ;;
    setup)
        # ... existing setup logic unchanged ...
```

**Step 3: Update `show_gpu_help` in `lib/cli.sh:233-256`**

Replace the help text:

```bash
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
```

Also update the duplicate `show_gpu_help` in `cmds/gpu.sh:376-399` to match.

**Step 4: Update references in status output**

In `gpu_info` (formerly `gpu_status`), line ~115-116, change:
- `"Run 'ctdev gpu setup' to configure driver signing."` (keep)
- `"Run 'ctdev gpu setup --recover' after a CMOS reset."` (keep)

These are already correct.

**Step 5: Commit**

```bash
git add cmds/gpu.sh lib/cli.sh
git commit -m "refactor: merge gpu status into gpu info subcommand"
```

---

### Task 2: Expand GRUB configuration in `configure linux-mint`

**Files:**
- Modify: `cmds/configure.sh` — functions `linux_mint_apply`, `linux_mint_show`, `linux_mint_reset`

**Step 1: Add GRUB helper function**

Add a new helper at the top of the Linux Mint section (after `linux_mint_show` helper functions, around line 440) that sets a GRUB variable idempotently:

```bash
# Set a GRUB variable in /etc/default/grub
# Usage: set_grub_var "GRUB_TIMEOUT" "0"
set_grub_var() {
    local var="$1"
    local value="$2"
    local grub_file="/etc/default/grub"
    [[ -f "$grub_file" ]] || return 1

    if grep -q "^${var}=" "$grub_file"; then
        maybe_sudo sed -i "s/^${var}=.*/${var}=${value}/" "$grub_file"
    else
        echo "${var}=${value}" | maybe_sudo tee -a "$grub_file" > /dev/null
    fi
}

# Add a parameter to GRUB_CMDLINE_LINUX_DEFAULT if not already present
add_grub_cmdline_param() {
    local param="$1"
    local grub_file="/etc/default/grub"
    [[ -f "$grub_file" ]] || return 1

    if ! grep -q "$param" "$grub_file"; then
        maybe_sudo sed -i "s/\\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\\)\"/\\1 ${param}\"/" "$grub_file"
    fi
}

# Remove a parameter from GRUB_CMDLINE_LINUX_DEFAULT
remove_grub_cmdline_param() {
    local param="$1"
    local grub_file="/etc/default/grub"
    [[ -f "$grub_file" ]] || return 1

    maybe_sudo sed -i "s/ ${param}//" "$grub_file"
}
```

**Step 2: Expand `linux_mint_apply` GRUB section**

Replace the existing NVIDIA GRUB block (lines 678-699) with a comprehensive GRUB section. Insert before the NVIDIA suspend block:

```bash
    # GRUB Configuration
    log_info "Configuring GRUB..."
    local grub_file="/etc/default/grub"
    local grub_changed=false

    if [[ -f "$grub_file" ]]; then
        # Instant boot (use F11 during POST for BIOS boot menu)
        set_grub_var "GRUB_TIMEOUT_STYLE" "hidden"
        set_grub_var "GRUB_TIMEOUT" "0"

        # Disable os-prober (we use BIOS boot menu for dual boot)
        set_grub_var "GRUB_DISABLE_OS_PROBER" "true"

        # Fix Linux Mint os-prober override if present
        local mint_grub="/etc/default/grub.d/50_linuxmint.cfg"
        if [[ -f "$mint_grub" ]] && grep -q "GRUB_DISABLE_OS_PROBER=false" "$mint_grub"; then
            maybe_sudo sed -i 's/GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=true/' "$mint_grub"
        fi

        grub_changed=true
    fi

    # NVIDIA GRUB parameters (only if NVIDIA driver is loaded)
    if lsmod | grep -q "^nvidia "; then
        log_info "Configuring NVIDIA kernel parameters..."
        add_grub_cmdline_param "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        add_grub_cmdline_param "nvidia.NVreg_EnableS0ixPowerManagement=0"
        add_grub_cmdline_param "pcie_aspm=off"
        grub_changed=true
    fi

    if [[ "$grub_changed" == "true" ]]; then
        maybe_sudo update-grub
        log_success "GRUB configured"
        log_info "GRUB timeout 0 = instant Linux boot. Press F11 during POST for BIOS boot menu to select Windows."
    fi
```

Remove the old NVIDIA GRUB block that was inside the `if lsmod | grep -q "^nvidia "` conditional (lines 682-690 of the original).

**Step 3: Expand `linux_mint_show` with GRUB section**

Add a GRUB section to `linux_mint_show` (after the "NVIDIA Suspend:" section, around line 603):

```bash
    echo "GRUB:"
    if [[ -f /etc/default/grub ]]; then
        local grub_val
        grub_val=$(grep "^GRUB_TIMEOUT_STYLE=" /etc/default/grub 2>/dev/null | cut -d= -f2 || echo "<not set>")
        printf "  %-40s %s\n" "Timeout style:" "$grub_val"
        grub_val=$(grep "^GRUB_TIMEOUT=" /etc/default/grub 2>/dev/null | cut -d= -f2 || echo "<not set>")
        printf "  %-40s %s\n" "Timeout:" "$grub_val"
        grub_val=$(grep "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub 2>/dev/null | cut -d= -f2 || echo "<not set>")
        printf "  %-40s %s\n" "OS prober disabled:" "$grub_val"
        local cmdline
        cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub 2>/dev/null | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"' || echo "<not set>")
        printf "  %-40s %s\n" "Kernel params:" "$cmdline"
    else
        printf "  %-40s %s\n" "GRUB config:" "not found"
    fi
    echo ""
```

**Step 4: Expand `linux_mint_reset` with GRUB reset**

Add GRUB reset to `linux_mint_reset` (before the existing NVIDIA reset block):

```bash
    log_info "Resetting GRUB settings..."
    local grub_file="/etc/default/grub"
    if [[ -f "$grub_file" ]]; then
        set_grub_var "GRUB_TIMEOUT_STYLE" "menu"
        set_grub_var "GRUB_TIMEOUT" "10"
        set_grub_var "GRUB_DISABLE_OS_PROBER" "false"

        local mint_grub="/etc/default/grub.d/50_linuxmint.cfg"
        if [[ -f "$mint_grub" ]] && grep -q "GRUB_DISABLE_OS_PROBER=true" "$mint_grub"; then
            maybe_sudo sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' "$mint_grub"
        fi
    fi
```

Also update the existing NVIDIA reset (lines 763-774) to remove the additional params:

```bash
    if lsmod | grep -q "^nvidia "; then
        log_info "Resetting NVIDIA settings..."
        remove_grub_cmdline_param "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        remove_grub_cmdline_param "nvidia.NVreg_EnableS0ixPowerManagement=0"
        remove_grub_cmdline_param "pcie_aspm=off"
        maybe_sudo update-grub
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-persistenced; do
            maybe_sudo systemctl disable "${svc}.service" 2>/dev/null || true
        done
    fi
```

**Step 5: Update dry-run output**

In the `linux_mint_apply` dry-run block (lines 609-621), add:
```bash
        log_info "[DRY-RUN] Would configure GRUB (timeout=0, hidden, os-prober disabled)"
```

And in reset dry-run:
```bash
        log_info "[DRY-RUN] Would reset GRUB settings (timeout=10, menu, os-prober enabled)"
```

**Step 6: Commit**

```bash
git add cmds/configure.sh
git commit -m "feat: expand GRUB configuration in configure linux-mint"
```

---

### Task 3: Add system services to `configure linux-mint`

**Files:**
- Modify: `cmds/configure.sh` — `linux_mint_apply`, `linux_mint_show`, `linux_mint_reset`

**Step 1: Add services to `linux_mint_apply`**

After the NVIDIA suspend services loop (line ~697), add `nvidia-persistenced`:

```bash
        # Enable NVIDIA persistence daemon
        if systemctl list-unit-files "nvidia-persistenced.service" &>/dev/null; then
            maybe_sudo systemctl enable "nvidia-persistenced.service" 2>/dev/null || true
        fi
```

After the NVIDIA block (outside the `if lsmod` check), add fstrim:

```bash
    # Enable SSD TRIM timer
    log_info "Configuring SSD TRIM..."
    if systemctl list-unit-files "fstrim.timer" &>/dev/null; then
        maybe_sudo systemctl enable fstrim.timer 2>/dev/null || true
        maybe_sudo systemctl start fstrim.timer 2>/dev/null || true
        log_success "fstrim.timer enabled"
    fi
```

**Step 2: Add to `linux_mint_show`**

In the "NVIDIA Suspend:" section, add `nvidia-persistenced` to the services loop:

```bash
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-persistenced; do
```

After the NVIDIA section, add:

```bash
    echo "Storage:"
    local fstrim_state
    fstrim_state=$(systemctl is-enabled "fstrim.timer" 2>/dev/null || echo "not found")
    printf "  %-40s %s\n" "fstrim.timer:" "$fstrim_state"
    echo ""
```

**Step 3: Add to `linux_mint_reset`**

Add `nvidia-persistenced` to the NVIDIA services disable loop:

```bash
        for svc in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-persistenced; do
```

Add fstrim reset:

```bash
    log_info "Resetting fstrim..."
    maybe_sudo systemctl stop fstrim.timer 2>/dev/null || true
    maybe_sudo systemctl disable fstrim.timer 2>/dev/null || true
```

**Step 4: Update dry-run blocks**

Add to apply dry-run:
```bash
        log_info "[DRY-RUN] Would enable fstrim.timer for SSD TRIM"
```

Add to reset dry-run:
```bash
        log_info "[DRY-RUN] Would disable fstrim.timer"
```

**Step 5: Commit**

```bash
git add cmds/configure.sh
git commit -m "feat: add nvidia-persistenced and fstrim to configure linux-mint"
```

---

### Task 4: Create `ctdev cleanup` command

**Files:**
- Create: `cmds/cleanup.sh`

**Step 1: Create `cmds/cleanup.sh` with kernel cleanup**

```bash
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
        log_info "Kernel cleanup is not applicable on macOS."
        return 0
    fi

    if [[ "$PKG_MGR" != "apt" ]]; then
        log_warning "Kernel cleanup is only supported on apt-based systems."
        return 0
    fi

    log_step "Kernel Cleanup"
    echo

    local current_kernel
    current_kernel=$(uname -r)
    log_info "Running kernel: $current_kernel"

    # Get all installed kernel image packages, sorted by version
    local all_kernels=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        all_kernels+=("$pkg")
    done < <(dpkg --list | grep -E "^ii\s+linux-image-[0-9]" | awk '{print $2}' | sort -V)

    if [[ ${#all_kernels[@]} -eq 0 ]]; then
        log_info "No kernel packages found."
        return 0
    fi

    echo "Installed kernels (${#all_kernels[@]}):"
    for pkg in "${all_kernels[@]}"; do
        local ver="${pkg#linux-image-}"
        if [[ "$ver" == "$current_kernel" ]]; then
            echo "  $pkg (current)"
        else
            echo "  $pkg"
        fi
    done
    echo

    # Determine which to keep: current kernel + one previous
    local keep_current="linux-image-${current_kernel}"
    local keep_previous=""
    for pkg in "${all_kernels[@]}"; do
        if [[ "$pkg" == "$keep_current" ]]; then
            break
        fi
        keep_previous="$pkg"
    done

    # Build removal list
    local remove_kernels=()
    for pkg in "${all_kernels[@]}"; do
        if [[ "$pkg" == "$keep_current" ]]; then
            continue
        fi
        if [[ -n "$keep_previous" && "$pkg" == "$keep_previous" ]]; then
            continue
        fi
        remove_kernels+=("$pkg")
    done

    if [[ ${#remove_kernels[@]} -eq 0 ]]; then
        log_success "No old kernels to remove."
        return 0
    fi

    echo "Will keep:"
    echo "  $keep_current (current)"
    [[ -n "$keep_previous" ]] && echo "  $keep_previous (previous)"
    echo
    echo "Will remove (${#remove_kernels[@]}):"
    for pkg in "${remove_kernels[@]}"; do
        echo "  $pkg"
        # Also find matching headers
        local header_pkg="${pkg/linux-image-/linux-headers-}"
        if dpkg -l "$header_pkg" &>/dev/null; then
            echo "  $header_pkg"
        fi
    done
    echo

    # Confirmation
    if [[ "${FORCE:-false}" != "true" && "${DRY_RUN:-false}" != "true" ]]; then
        read -rp "Remove these kernels? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Cancelled."
            return 0
        fi
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove ${#remove_kernels[@]} kernel(s) and matching headers"
        return 0
    fi

    # Remove kernels and headers
    for pkg in "${remove_kernels[@]}"; do
        local header_pkg="${pkg/linux-image-/linux-headers-}"
        run_cmd maybe_sudo apt remove -y "$pkg" || true
        if dpkg -l "$header_pkg" &>/dev/null 2>&1; then
            run_cmd maybe_sudo apt remove -y "$header_pkg" || true
        fi
    done

    # Purge rc entries
    local rc_packages
    rc_packages=$(dpkg --list | grep "^rc" | awk '{print $2}' || true)
    if [[ -n "$rc_packages" ]]; then
        log_info "Purging removed-but-config-remaining packages..."
        echo "$rc_packages" | while read -r pkg; do
            run_cmd maybe_sudo dpkg --purge "$pkg" || true
        done
    fi

    run_cmd maybe_sudo apt autoremove -y --quiet
    run_cmd maybe_sudo update-grub

    echo
    log_success "Kernel cleanup complete"

    # Show remaining kernels
    echo "Remaining kernels:"
    dpkg --list | grep -E "^ii\s+linux-image-[0-9]" | awk '{print "  " $2}'
}

###############################################################################
# Subcommand: apt
###############################################################################

cleanup_apt() {
    if [[ "$PKG_MGR" != "apt" ]]; then
        log_info "APT cleanup is only available on apt-based systems."
        return 0
    fi

    log_step "APT Repository Audit"
    echo

    local sources_dir="/etc/apt/sources.list.d"
    if [[ ! -d "$sources_dir" ]]; then
        log_info "No sources.list.d directory found."
        return 0
    fi

    # List all repo files
    local repo_files=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        repo_files+=("$file")
    done < <(find "$sources_dir" -maxdepth 1 -name "*.list" -o -name "*.sources" 2>/dev/null | sort)

    if [[ ${#repo_files[@]} -eq 0 ]]; then
        log_info "No additional APT repositories configured."
        return 0
    fi

    log_info "Found ${#repo_files[@]} repository file(s):"
    echo

    local removed_any=false

    for repo_file in "${repo_files[@]}"; do
        local repo_name
        repo_name=$(basename "$repo_file")
        echo "  Repository: $repo_name"

        # Show packages installed from this repo (best effort)
        local repo_basename="${repo_name%.list}"
        repo_basename="${repo_basename%.sources}"

        # Try to find associated keyring
        local keyring=""
        for dir in /etc/apt/trusted.gpg.d /usr/share/keyrings; do
            local found
            found=$(find "$dir" -maxdepth 1 -name "*${repo_basename}*" 2>/dev/null | head -1)
            if [[ -n "$found" ]]; then
                keyring="$found"
                echo "  Keyring: $keyring"
                break
            fi
        done

        echo

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            echo "  [DRY-RUN] Would prompt for removal"
            echo
            continue
        fi

        read -rp "  Remove this repository? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            run_cmd maybe_sudo rm -f "$repo_file"
            if [[ -n "$keyring" ]]; then
                run_cmd maybe_sudo rm -f "$keyring"
            fi
            log_success "Removed $repo_name"
            removed_any=true
        fi
        echo
    done

    if [[ "$removed_any" == "true" ]]; then
        log_info "Running cleanup..."
        run_cmd maybe_sudo apt update -qq 2>/dev/null || true
        run_cmd maybe_sudo apt autoremove -y --quiet
        run_cmd maybe_sudo apt clean
        log_success "APT cleanup complete"
    else
        log_info "No repositories removed."
    fi
}

###############################################################################
# Main dispatcher
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
```

**Step 2: Verify ShellCheck**

Run: `shellcheck cmds/cleanup.sh`
Expected: No errors (warnings about `read` in loops are acceptable)

**Step 3: Commit**

```bash
git add cmds/cleanup.sh
git commit -m "feat: add ctdev cleanup command with kernels and apt subcommands"
```

---

### Task 5: Create `ctdev setup` command

**Files:**
- Create: `cmds/setup.sh`

**Step 1: Create `cmds/setup.sh`**

```bash
#!/usr/bin/env bash

# ctdev setup - Master setup orchestration for fresh installs

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
            --skip-update) skip_update=true ;;
            --skip-gpu) skip_gpu=true ;;
            --skip-configure) skip_configure=true ;;
            --skip-cleanup) skip_cleanup=true ;;
        esac
    done

    log_step "ctdev Setup — $(date +%Y-%m-%d)"
    log_info "OS: $OS"
    echo

    local step=0

    # Step 1: System update
    step=$((step + 1))
    if [[ "$skip_update" == "true" ]]; then
        log_info "Step $step: System update (skipped)"
    else
        log_step "Step $step: System Update"
        source "$DOTFILES_ROOT/cmds/update.sh"
        cmd_update -y
        echo
    fi

    # Step 2: GPU setup (Linux only, NVIDIA + Secure Boot)
    if [[ "$OS" != "macos" ]]; then
        step=$((step + 1))
        if [[ "$skip_gpu" == "true" ]]; then
            log_info "Step $step: GPU setup (skipped)"
        else
            log_step "Step $step: GPU Setup"
            source "$DOTFILES_ROOT/lib/gpu.sh"
            source "$DOTFILES_ROOT/cmds/gpu.sh"

            # Only run if NVIDIA hardware detected and Secure Boot enabled
            local has_nvidia=false
            if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi nvidia; then
                has_nvidia=true
            fi

            if [[ "$has_nvidia" == "true" ]] && is_secure_boot_enabled; then
                gpu_setup
            elif [[ "$has_nvidia" == "true" ]]; then
                log_info "NVIDIA detected but Secure Boot is disabled — skipping driver signing"
            else
                log_info "No NVIDIA GPU detected — skipping"
            fi
            echo
        fi
    fi

    # Step 3: System configuration
    step=$((step + 1))
    if [[ "$skip_configure" == "true" ]]; then
        log_info "Step $step: System configuration (skipped)"
    else
        log_step "Step $step: System Configuration"
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
        echo
    fi

    # Step 4-5: Cleanup (Linux only)
    if [[ "$OS" != "macos" ]]; then
        step=$((step + 1))
        if [[ "$skip_cleanup" == "true" ]]; then
            log_info "Step $step: Cleanup (skipped)"
        else
            log_step "Step $step: Kernel Cleanup"
            source "$DOTFILES_ROOT/cmds/cleanup.sh"
            cleanup_kernels
            echo

            step=$((step + 1))
            log_step "Step $step: APT Repository Audit"
            cleanup_apt
            echo
        fi
    fi

    echo
    log_success "Setup complete!"
    log_info "Some changes may require a logout or reboot to take full effect."
}
```

**Step 2: Verify ShellCheck**

Run: `shellcheck cmds/setup.sh`
Expected: No errors

**Step 3: Commit**

```bash
git add cmds/setup.sh
git commit -m "feat: add ctdev setup command for fresh install orchestration"
```

---

### Task 6: Register new commands in CLI

**Files:**
- Modify: `lib/cli.sh:29-65` (add setup/cleanup to help)
- Modify: `lib/cli.sh:314-329` (add to valid commands)
- Modify: `ctdev:72-83` (add help dispatch)

**Step 1: Update `show_main_help` in `lib/cli.sh:29-65`**

Add `setup` and `cleanup` to the commands list:

```bash
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
```

Add examples:
```
    ctdev setup                          Run full fresh-install setup
    ctdev cleanup kernels                Remove old kernel versions
```

**Step 2: Add help functions for new commands**

Add to `lib/cli.sh` after `show_gpu_help` (after line 256):

Note: The actual help implementations live in `cmds/setup.sh` and `cmds/cleanup.sh`. We just need stub functions in `cli.sh` that source and call them:

```bash
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
```

**Step 3: Add to `require_command` in `lib/cli.sh:314-329`**

Change the valid commands string:

```bash
    local valid_commands="install uninstall update list info configure gpu setup cleanup"
```

**Step 4: Add help dispatch in `ctdev:72-83`**

Add the new cases:

```bash
        setup)     show_setup_help ;;
        cleanup)   show_cleanup_help ;;
```

**Step 5: Commit**

```bash
git add lib/cli.sh ctdev
git commit -m "feat: register setup and cleanup commands in CLI"
```

---

### Task 7: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:7-22` (command reference)

**Step 1: Update command list**

Replace the ctdev CLI section:

```bash
ctdev install <component...>    # Install specific components
ctdev uninstall <component...>  # Remove specific components
ctdev update [-y]               # Update system packages and components
ctdev update --check            # List available updates without installing
ctdev update --refresh-keys     # Refresh APT GPG keys before updating
ctdev list                      # List components with status
ctdev info                      # Show system information
ctdev configure git             # Configure git user
ctdev configure macos           # Configure macOS defaults (macOS only)
ctdev configure linux-mint      # Configure Linux Mint defaults (Linux Mint only)
ctdev gpu info                  # Show GPU info and signing status
ctdev gpu setup                 # Configure MOK signing for NVIDIA drivers
ctdev setup                     # Run full fresh-install setup
ctdev cleanup kernels           # Remove old kernel versions
ctdev cleanup apt               # Audit and clean APT repositories
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with setup, cleanup, and gpu info commands"
```

---

### Task 8: Final verification

**Step 1: Run ShellCheck on all modified files**

```bash
shellcheck cmds/gpu.sh cmds/configure.sh cmds/setup.sh cmds/cleanup.sh lib/cli.sh
```

Expected: No errors

**Step 2: Verify help output**

```bash
./ctdev --help
./ctdev gpu --help
./ctdev setup --help
./ctdev cleanup --help
```

Expected: All show updated help text with new commands

**Step 3: Verify dry-run**

```bash
./ctdev setup --dry-run
./ctdev cleanup kernels --dry-run
```

Expected: Shows what would be done without making changes

**Step 4: Fix any issues found, then commit**

```bash
git add -A
git commit -m "fix: address shellcheck and verification issues"
```

(Only if changes were needed)
