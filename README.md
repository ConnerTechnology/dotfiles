# dotfiles

Modular dotfiles for macOS and Linux. Managed via the `ctdev` CLI.

## Install

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/ConnerTechnology/dotfiles/main/install.sh | bash
```

**Or manually:**

```bash
git clone https://github.com/ConnerTechnology/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

## ctdev CLI

```bash
ctdev install <component...>    # Install specific components
ctdev uninstall <component...>  # Remove specific components
ctdev update [-y]               # Update system packages and components
ctdev update --check            # List available updates without installing
ctdev update --refresh-keys     # Refresh APT GPG keys before updating
ctdev info                      # Show system information
ctdev configure git             # Configure git user
ctdev gpu info                  # Show GPU hardware info and signing status
ctdev gpu setup                 # Configure MOK signing for NVIDIA drivers
ctdev setup                     # Set up and configure your OS
ctdev cleanup                   # Run all cleanup tasks
```

**Flags:** `--help`, `--dry-run`, `--verbose`, `--force`, `--version`

## Components

34 components available. Run `ctdev install --help` to see all.

**Desktop Applications:**
1password, chatgpt, chrome, cleanmymac, claude-desktop, dbeaver, ghostty, linear, logi-options, slack, vscode

**CLI Tools:**
age, bleachbit, btop, bun, claude-code, codex, docker, doctl, earlyoom, gh, git-spice, helm, jq, kubectl, shellcheck, sops, terraform, tmux

**Configuration & Languages:**
fonts, git, node, ruby, zsh

Components are defined in `lib/components.sh`. Each component has an `install.sh` and `uninstall.sh` in `components/<name>/`.

## Examples

```bash
ctdev install zsh git                # Install shell and git config
ctdev install node bun               # Install Node.js and Bun
ctdev update                         # Update all installed components
ctdev update -y                      # Update without prompting
ctdev configure git                  # Configure git user (global)
ctdev configure git --local          # Configure git for current repo
ctdev setup                          # Run full fresh-install setup
ctdev setup --show                   # Show current system configuration
ctdev cleanup                        # Run all cleanup tasks
```

## DevContainers

Add to your VS Code `settings.json`:

```json
{
  "dotfiles.repository": "https://github.com/ConnerTechnology/dotfiles.git",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "./devcontainer.sh"
}
```

This automatically installs zsh, Oh My Zsh, and Pure prompt in devcontainers.

## Platform Support

- **macOS** - Homebrew
- **Ubuntu/Debian** - apt
- **Fedora/RHEL** - dnf
- **Arch** - pacman

## Structure

```
dotfiles/
├── ctdev              # CLI entry point
├── lib/               # Shared utilities
├── cmds/              # CLI commands
└── components/        # Installable components (one dir per component)
```

## Customization

- `components/zsh/aliases.zsh` - Command aliases
- `components/zsh/exports.zsh` - Environment variables
- `components/zsh/path.zsh` - PATH configuration

## Uninstall

```bash
~/dotfiles/uninstall.sh          # Remove ctdev CLI
ctdev uninstall <component...>   # Remove specific components first
```

The uninstall script removes the ctdev symlink and config directory. The dotfiles repo remains at `~/dotfiles` - delete it manually if desired.

## License

MIT
