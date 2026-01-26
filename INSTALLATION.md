# Installation Guide

Complete setup instructions for ktty-trmnl-tmx.

---

## Quick Start

```bash
git clone https://github.com/hmbldv/ktty-trmnl-tmx.git
cd ktty-trmnl-tmx
./install.sh
```

The installer will:
1. Detect your OS (macOS, Debian/Ubuntu, Fedora, Arch)
2. Detect VM/SSH environments and recommend the appropriate terminal
3. Prompt you to choose between **Kitty** or **Native Terminal** mode
4. Install JetBrainsMono Nerd Font and all components
5. Symlink configs to the correct locations

---

## Terminal Mode Selection

### Option 1: Kitty (Default for physical machines)

GPU-accelerated terminal with advanced features like image display, ligatures, and SSH integration.

**Best for:** Native installs on physical machines with direct display access.

### Option 2: Native Terminal (Default for VMs/SSH)

Uses your system's default terminal (Terminal.app on macOS, existing terminal on Linux).

**Best for:** Virtual machines, SSH sessions, remote servers, or when Kitty isn't needed.

**Note:** When using Native Terminal mode on macOS, set the font manually:
1. Terminal → Settings → Profiles → [Your Profile] → Text
2. Click "Change..." next to Font
3. Select "JetBrainsMono Nerd Font Mono" at size 12

### Environment Detection

The installer automatically detects:
- **Virtual machines** — Parallels, VMware, VirtualBox, QEMU, KVM, Xen, Hyper-V
- **SSH sessions** — Remote connections without direct display access

When detected, the installer recommends Native Terminal since Kitty requires OpenGL 3.3 and direct display access.

---

## Repository Structure

```
ktty-trmnl-tmx/
├── install.sh              # Bootstrap script
├── kitty/
│   ├── kitty.conf          # Main Kitty config
│   └── themes/
│       ├── catppuccin-spacedust.conf  # Default theme
│       ├── spacedust.conf
│       └── earthsong.conf
├── tmux/
│   └── tmux.conf           # tmux config
├── gitmux/
│   └── gitmux.conf         # Git status for tmux
└── zsh/
    ├── zshrc               # Main zsh config
    ├── aliases.zsh         # Shared aliases
    └── starship.toml       # Starship prompt config
```

---

## Config Locations (After Install)

| Config | Location |
|--------|----------|
| Kitty | `~/.config/kitty/kitty.conf` |
| tmux | `~/.tmux.conf` |
| zsh | `~/.zshrc` |
| Starship | `~/.config/starship.toml` |
| gitmux | `~/.gitmux.conf` |
| Fonts | System font directory |

---

## Keyboard Shortcuts

### tmux (Prefix: Ctrl+A)

| Action | Shortcut |
|--------|----------|
| **Prefix key** | `Ctrl+A` |
| Vertical split | `Prefix` then `\|` |
| Horizontal split | `Prefix` then `-` |
| Navigate panes | `Prefix` then `h/j/k/l` |
| Resize panes | `Prefix` then `H/J/K/L` |
| New window | `Prefix` then `c` |
| Next/Prev window | `Prefix` then `n/p` |
| Detach session | `Prefix` then `d` |
| Reload config | `Prefix` then `r` |

### Kitty

| Action | Shortcut |
|--------|----------|
| New tab | `Ctrl+Shift+T` |
| Close tab | `Ctrl+Shift+W` |
| Next/Prev tab | `Ctrl+Shift+Right/Left` |
| Go to tab N | `Ctrl+Shift+[1-5]` |
| New window | `Ctrl+Shift+Enter` |
| Navigate windows | `Ctrl+Shift+[/]` |
| Zoom pane | `Ctrl+Shift+Z` |
| Reload config | `Ctrl+Shift+F5` |
| Increase font | `Ctrl+Shift+=` |
| Decrease font | `Ctrl+Shift+-` |
| Clear terminal | `Cmd+K` (macOS) |

---

## Shell Aliases

```bash
# Navigation
..          # cd ..
...         # cd ../..

# Kitty tools
s           # kitty +kitten ssh
icat        # kitty +kitten icat (display images)
kdiff       # kitty +kitten diff

# Git
gs          # git status
ga          # git add
gc          # git commit
gp          # git push
gl          # git pull
glog        # git log --oneline --graph

# Utilities
reload      # source ~/.zshrc
path        # echo $PATH (one per line)
```

---

## Kitty Tools (Kittens)

```bash
# SSH with full Kitty features on remote
kitty +kitten ssh hostname

# Display images in terminal
kitty +kitten icat image.png

# Side-by-side diff
kitty +kitten diff file1 file2

# Unicode character picker
kitty +kitten unicode_input
```

---

## Manual Installation

If you prefer not to run the install script:

```bash
# macOS
brew install --cask kitty font-jetbrains-mono-nerd-font
brew install tmux starship zsh-syntax-highlighting zsh-autosuggestions

# Debian/Ubuntu
sudo apt install kitty tmux zsh zsh-syntax-highlighting zsh-autosuggestions
curl -sS https://starship.rs/install.sh | sh
# Font: download from https://github.com/ryanoasis/nerd-fonts/releases

# Symlink configs
ln -sf $(pwd)/kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -sf $(pwd)/kitty/themes ~/.config/kitty/themes
ln -sf $(pwd)/tmux/tmux.conf ~/.tmux.conf
ln -sf $(pwd)/zsh/zshrc ~/.zshrc
ln -sf $(pwd)/zsh/starship.toml ~/.config/starship.toml
ln -sf $(pwd)/gitmux/gitmux.conf ~/.gitmux.conf
```

---

## Updating

```bash
cd ktty-trmnl-tmx
git pull
# Configs are symlinked—changes apply immediately

# Reload each component:
# Kitty: Ctrl+Shift+F5
# zsh: source ~/.zshrc (or `reload` alias)
# tmux: Prefix + r
```

---

## Adding a New Theme

1. Add theme file to `kitty/themes/`
2. Update `kitty.conf`:
   ```conf
   include themes/your-theme.conf
   ```
3. Reload: `Ctrl+Shift+F5`

Or use the built-in theme picker:
```bash
kitty +kitten themes
```

---

## Troubleshooting

### Icons show as boxes or question marks
The font isn't set correctly. Install JetBrainsMono Nerd Font and set it in your terminal preferences.

### Kitty won't start in a VM
Kitty requires OpenGL 3.3 which most VM graphics drivers don't support. Run the installer again and choose "Native Terminal" mode.

### tmux prefix key doesn't work
This config uses `Ctrl+A` as the prefix, not the default `Ctrl+B`. If you have existing tmux muscle memory, it may take adjustment.

### First tmux launch looks broken
Run `Ctrl+A` then `I` (capital I) to install tmux plugins via TPM.

### Starship prompt is slow in large repos
Starship checks git status which can be slow in massive repositories. This is expected behavior.

---

## Requirements

- **Homebrew** (macOS only) — Required for package installation
- **sudo access** (Linux only) — Required to install zsh and plugins via package manager
- **Nerd Font** — JetBrainsMono is installed automatically; required for OS icons in prompt

---

## Uninstall

To restore your previous configuration:

```bash
# The installer backs up existing configs to ~/.config-backup/
# Restore them manually if needed

# Remove symlinks
rm ~/.tmux.conf ~/.zshrc ~/.config/starship.toml ~/.gitmux.conf
rm -rf ~/.config/kitty

# Remove the repo
rm -rf ~/ktty-trmnl-tmx
```

---

## License

MIT
