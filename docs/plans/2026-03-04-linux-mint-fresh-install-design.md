# Design: Linux Mint Fresh Install Setup

**Date:** 2026-03-04
**Status:** Approved

## Goal

Extend the ctdev CLI to support a comprehensive post-install setup for fresh Linux Mint (and macOS) systems, without duplicating existing functionality.

## Gap Analysis

### Already Complete (No Changes)

| Feature | Location |
|---------|----------|
| NVIDIA Secure Boot detection, status, setup, recovery | `lib/gpu.sh` + `cmds/gpu.sh` |
| MOK key generation, clutter cleanup, DKMS config | `lib/gpu.sh` |
| MOK enrollment + reboot instructions | `cmds/gpu.sh` |
| NVIDIA suspend services (enable) | `cmds/configure.sh` → `linux_mint_apply` |
| NVIDIA PreserveVideoMemory GRUB param | `cmds/configure.sh` → `linux_mint_apply` |
| System update + autoremove | `cmds/update.sh` |
| Colored logging, dry-run, help flags | `lib/logging.sh`, `lib/utils.sh` |

### Changes Required

## Change 1: Merge `gpu status` into `gpu info`

**File:** `cmds/gpu.sh`

- Rename `gpu_status` logic into `gpu_info`
- `ctdev gpu info` displays: hardware info (model, VRAM, temp, power, CUDA, driver) followed by all Secure Boot signing checks
- Keep `status` as an undocumented alias for backwards compat (just calls `gpu_info`)
- Update help text

## Change 2: Expand GRUB configuration in `configure linux-mint`

**File:** `cmds/configure.sh` → `linux_mint_apply`

Add GRUB settings (apply, show, reset):

- `GRUB_TIMEOUT_STYLE=hidden`
- `GRUB_TIMEOUT=0`
- `GRUB_DISABLE_OS_PROBER=true` (in both `/etc/default/grub` and `/etc/default/grub.d/50_linuxmint.cfg`)
- Expand `GRUB_CMDLINE_LINUX_DEFAULT` with: `nvidia.NVreg_EnableS0ixPowerManagement=0 pcie_aspm=off` (in addition to existing `nvidia.NVreg_PreserveVideoMemoryAllocations=1`)
- Run `update-grub` after changes
- Print note: "GRUB timeout 0 = instant Linux boot. Press F11 during POST for BIOS boot menu to select Windows."

**Reset behavior:** Restore `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=10`, remove extra NVIDIA params, set `GRUB_DISABLE_OS_PROBER=false`.

**Show behavior:** Display current values for all GRUB settings.

## Change 3: Additional system services in `configure linux-mint`

**File:** `cmds/configure.sh` → `linux_mint_apply`

Add to apply/show/reset:

- `systemctl enable nvidia-persistenced` (apply) / `disable` (reset)
- `systemctl enable fstrim.timer` + `systemctl start fstrim.timer` (apply) / `disable` + `stop` (reset)

## Change 4: New command `ctdev cleanup`

**New file:** `cmds/cleanup.sh`

### `ctdev cleanup kernels`

1. Detect running kernel (`uname -r`)
2. List installed kernels (`dpkg --list | grep linux-image`)
3. Keep current + one previous version
4. Remove all other kernel images AND matching headers
5. Purge `rc` (removed-but-config-remaining) entries
6. Run `apt autoremove` and `update-grub`
7. Show before/after summary
8. Linux-only (exit 0 with message on macOS)

### `ctdev cleanup apt`

1. List all repos from `/etc/apt/sources.list.d/`
2. For each repo, show installed packages from it
3. Interactive prompt to remove unwanted repos + packages + GPG keys (check `/etc/apt/trusted.gpg.d/` and `/usr/share/keyrings/`)
4. Run `apt autoremove && apt clean` after removal
5. Linux/apt-only

### Help and flags

- `ctdev cleanup --help`
- `--dry-run` support
- `--force` to skip confirmations for kernel cleanup

## Change 5: New command `ctdev setup`

**New file:** `cmds/setup.sh`

Cross-platform master orchestration. Detects OS and runs appropriate steps.

### Linux Mint steps (in order)

1. **System update** — calls `cmd_update -y`
2. **GPU setup** — calls `gpu_setup` if NVIDIA hardware detected + Secure Boot enabled
3. **System configuration** — calls `configure_linux_mint`
4. **Kernel cleanup** — calls kernel cleanup logic
5. **APT cleanup** — calls apt cleanup logic (interactive)

### macOS steps (in order)

1. **System update** — calls `cmd_update -y`
2. **System configuration** — calls `configure_macos`

### Flags

- `--skip-update` — skip system update step
- `--skip-gpu` — skip GPU setup step
- `--skip-configure` — skip system configuration step
- `--skip-cleanup` — skip kernel + APT cleanup steps
- `--dry-run` — inherited, preview all changes
- `--help` — show usage

## Change 6: Register new commands

**Files:** `lib/cli.sh`, `ctdev`

- Add `setup` and `cleanup` to valid commands
- Add help dispatch cases
- Add `show_setup_help` and `show_cleanup_help` functions

## Change 7: Update CLAUDE.md

- Add `ctdev setup` and `ctdev cleanup` to the command reference
- Update `ctdev gpu` to show `info` instead of `status`/`sign` (remove `sign`, it's internal)

## File Changes Summary

| File | Change Type |
|------|-------------|
| `cmds/gpu.sh` | Modify — merge status into info |
| `cmds/configure.sh` | Modify — expand GRUB + services |
| `cmds/setup.sh` | **New** — master orchestration |
| `cmds/cleanup.sh` | **New** — kernel + apt cleanup |
| `lib/cli.sh` | Modify — register new commands |
| `ctdev` | Modify — add help dispatch |
| `CLAUDE.md` | Modify — update command reference |

## Non-goals

- No standalone scripts in `scripts/linux/` (everything lives in ctdev)
- No logging to `~/.local/share/dotfiles/setup.log` (ctdev already has colored output; log file adds complexity for no benefit)
- No separate `lib.sh` (ctdev already has `lib/utils.sh` ecosystem)
