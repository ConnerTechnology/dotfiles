# Troubleshooting

## ctdev not found

```bash
./install.sh                    # Re-run install script
export PATH="$HOME/.local/bin:$PATH"
```

## Permission denied

ctdev uses `maybe_sudo` automatically. If you're in Docker without sudo, some installs will fail - check logs for alternatives.

## Component shows as not installed

ctdev uses markers in `~/.config/ctdev/`. If detection fails:

```bash
ctdev components install <component>  # Re-run to create marker
```

## Uninstalling

```bash
ctdev components uninstall <component...>   # Remove specific components
~/dotfiles/uninstall.sh          # Remove ctdev itself
```

The uninstall script will prompt to remove all components first, then removes the ctdev symlink and config directory.

## macOS

**Xcode popup:** Run `xcode-select --install` manually and wait for it to complete.

**Homebrew not found:** Add to shell profile:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"  # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # Intel
```

**"Operation not permitted" for defaults:** Grant Terminal full disk access in System Preferences > Security & Privacy.

## Linux

**Expired APT GPG key (EXPKEYSIG):** Re-download signing keys for installed components:
```bash
ctdev update --refresh-keys              # Refresh all keys
ctdev update --refresh-keys docker gh    # Refresh specific components
```

**Fonts not showing:** Run `fc-cache -fv` and restart terminal.

**Package manager not detected:** Run `ctdev info` to see what was detected, then install packages manually.

### Desktop Freezes (NVIDIA + Dual GPU)

Repeated system freezes on Linux Mint with Ryzen 7000 series (Raphael iGPU + discrete NVIDIA). The `amdgpu` driver loads for the unused iGPU and fails on suspend/resume cycles with `Unsupported suspend state 1`, causing system hangs. Additionally, NVIDIA suspend was not configured to preserve video memory allocations.

**1. Disable integrated GPU in BIOS** (recommended)

Disable the Ryzen iGPU in BIOS/UEFI to prevent the `amdgpu` kernel module from loading. Verify with:
```bash
lsmod | grep amdgpu   # Should return nothing
```

If BIOS toggle is unavailable, blacklist the module instead:
```bash
echo "blacklist amdgpu" | sudo tee /etc/modprobe.d/blacklist-amdgpu.conf
sudo update-initramfs -u
sudo reboot
```

**2. NVIDIA suspend stability** (automated by `ctdev configure linux-mint`)

`ctdev configure linux-mint` handles these automatically on NVIDIA systems:
- Adds `nvidia.NVreg_PreserveVideoMemoryAllocations=1` to GRUB kernel parameters
- Enables `nvidia-suspend`, `nvidia-resume`, and `nvidia-hibernate` systemd services

To apply manually instead:
```bash
# Add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub:
#   nvidia.NVreg_PreserveVideoMemoryAllocations=1
sudo update-grub

# Enable services
sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
```

**Pre-existing kernel parameters** (may also help, set these manually if needed):
- `nvidia.NVreg_EnableS0ixPowerManagement=0` — disables S0ix power management
- `pcie_aspm=off` — disables PCIe Active State Power Management

**Monitoring for regression:**
```bash
sudo nvme smart-log /dev/nvme0n1 | grep unsafe   # Unsafe shutdown count
sudo journalctl -b -1 -p err                      # Errors from previous boot
sudo smartctl -a /dev/nvme0n1                      # NVMe health
```

## Zsh

**Oh My Zsh not loading:** Check `ls -la ~/.zshrc` - should be a symlink. Re-run `ctdev components install zsh`.

**Pure prompt missing:** Delete `~/.zsh/pure` and reinstall: `ctdev components install zsh --force`.

## Node/Ruby

**Version manager not found:** Add to shell profile:
```bash
export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init -)"

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
```

**Build failing:** Install dependencies first:
```bash
# macOS
brew install openssl readline libyaml

# Ubuntu/Debian
sudo apt install build-essential libssl-dev libyaml-dev zlib1g-dev libffi-dev
```

## Debugging

```bash
ctdev --dry-run components install zsh   # Preview without changes
ctdev --verbose components install zsh   # More output
ctdev info                               # System diagnostics
ctdev components list                    # Show component status
```

## Still stuck?

Open an issue with `ctdev info` output and the failing command.
