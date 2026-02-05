# Installation Guide

Complete setup instructions for trmnl.

---

## Quick Start

```bash
git clone https://github.com/hmbldv/trmnl.git
cd trmnl
./install.sh
```

The installer will:
1. Detect your OS (macOS, Debian/Ubuntu, Fedora, Arch)
2. Detect VM/SSH environments and recommend the appropriate terminal
3. Prompt you to choose between **Kitty**, **Alacritty**, **Native Terminal**, or **All**
4. Install JetBrainsMono Nerd Font and all components
5. Symlink configs to the correct locations
6. Offer to set zsh as your default shell

---

## Terminal Mode Selection

### Option 1: Kitty (Default for physical machines)

GPU-accelerated terminal with advanced features like image display, ligatures, and SSH integration.

**Best for:** Native installs on physical machines with direct display access.

### Option 2: Alacritty

GPU-accelerated terminal with minimal configuration. Fast and lightweight.

**Best for:** Physical machines where you prefer a simpler terminal emulator.

### Option 3: Native Terminal (Default for VMs/SSH)

Uses your system's default terminal (Terminal.app on macOS, existing terminal on Linux). Installs shell, prompt, tmux, and all CLI tools—just no terminal emulator.

**Best for:** Virtual machines, SSH sessions, remote servers, or when you already have a terminal you like.

**Note:** When using Native Terminal mode on macOS, set the font manually:
1. Terminal → Settings → Profiles → [Your Profile] → Text
2. Click "Change..." next to Font
3. Select "JetBrainsMono Nerd Font Mono" at size 12

### Option 4: All

Installs both Kitty and Alacritty plus all tools. Use whichever terminal you prefer.

### Environment Detection

The installer automatically detects:
- **Virtual machines** — Parallels, VMware, VirtualBox, QEMU, KVM, Xen, Hyper-V
- **SSH sessions** — Remote connections without direct display access

When detected, the installer recommends Native Terminal since GPU-accelerated terminals require OpenGL 3.3 and direct display access.

---

## Repository Structure

```
trmnl/
├── install.sh              # Bootstrap script
├── alacritty/
│   └── alacritty.toml      # Alacritty config
├── kitty/
│   ├── kitty.conf          # Main Kitty config
│   ├── kitty.app.png       # Custom app icon
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
    ├── aliases.zsh          # Shared aliases
    └── starship.toml        # Starship prompt config
```

---

## Config Locations (After Install)

| Config | Location |
|--------|----------|
| Kitty | `~/.config/kitty/kitty.conf` |
| Alacritty | `~/.config/alacritty/alacritty.toml` |
| tmux | `~/.tmux.conf` |
| zsh | `~/.zshrc` |
| Starship | `~/.config/starship.toml` |
| gitmux | `~/.gitmux.conf` |
| Fonts | System font directory |

All configs are symlinked back to the repo—edit in either place.

---

## What Gets Installed

| Tool | Purpose |
|------|---------|
| JetBrainsMono Nerd Font | Icons in prompt and status bar |
| zsh | Shell with syntax highlighting and autosuggestions |
| Starship | Cross-shell prompt with git status and OS icons |
| tmux | Terminal multiplexer (split panes, persistent sessions) |
| TPM | Tmux Plugin Manager |
| gitmux | Git branch/status in tmux status bar |
| fzf | Fuzzy finder (Ctrl+R for history, Ctrl+T for files) |
| zoxide | Smart `cd` that learns your directories |
| fastfetch | System info on shell startup |
| Kitty | Terminal emulator (if selected) |
| Alacritty | Terminal emulator (if selected) |

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
| Install plugins | `Prefix` then `I` |

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

# Listing
ll          # ls -lah
la          # ls -A

# Safety
rm          # rm -i (prompts before delete)
cp          # cp -i
mv          # mv -i

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
gd          # git diff
gco         # git checkout
gb          # git branch
glog        # git log --oneline --graph

# Utilities
reload      # source ~/.zshrc
path        # echo $PATH (one per line)
c           # clear
h           # history
```

---

## Manual Installation

If you prefer not to run the install script:

```bash
# macOS
brew install --cask kitty alacritty font-jetbrains-mono-nerd-font
brew install tmux starship fzf zoxide fastfetch \
     zsh-syntax-highlighting zsh-autosuggestions

# Debian/Ubuntu
sudo apt install tmux zsh zsh-syntax-highlighting zsh-autosuggestions fzf
curl -sS https://starship.rs/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
# Font: download from https://github.com/ryanoasis/nerd-fonts/releases
# gitmux: download from https://github.com/arl/gitmux/releases

# Symlink configs
ln -sf $(pwd)/kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -sf $(pwd)/kitty/themes ~/.config/kitty/themes
ln -sf $(pwd)/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
ln -sf $(pwd)/tmux/tmux.conf ~/.tmux.conf
ln -sf $(pwd)/zsh/zshrc ~/.zshrc
ln -sf $(pwd)/zsh/starship.toml ~/.config/starship.toml
ln -sf $(pwd)/gitmux/gitmux.conf ~/.gitmux.conf
```

---

## Updating

```bash
cd trmnl
git pull
# Configs are symlinked—changes apply immediately

# Reload each component:
# Kitty: Ctrl+Shift+F5
# Alacritty: auto-reloads on save
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

### Kitty or Alacritty won't start in a VM
GPU-accelerated terminals require OpenGL 3.3 which most VM graphics drivers don't support. Run the installer again and choose "Terminal only" (option 3).

### tmux prefix key doesn't work
This config uses `Ctrl+A` as the prefix, not the default `Ctrl+B`. If you have existing tmux muscle memory, it may take adjustment.

### First tmux launch looks broken
Run `Ctrl+A` then `I` (capital I) to install tmux plugins via TPM.

### Starship prompt is slow in large repos
Starship checks git status which can be slow in massive repositories. This is expected behavior.

### fzf shows "invalid color specification"
The fzf color config requires fzf 0.44+. If your distro ships an older version, install from the [fzf GitHub releases](https://github.com/junegunn/fzf/releases).

---

## Requirements

- **Homebrew** (macOS only) — Required for package installation
- **sudo access** (Linux only) — Required to install packages via package manager (falls back to manual install without sudo)
- **Nerd Font** — JetBrainsMono is installed automatically; required for icons in prompt and status bar

---

## Uninstall

To restore your previous configuration:

```bash
# The installer backs up existing configs to *.bak files
# Check for .bak files and restore if needed

# Remove symlinks
rm ~/.tmux.conf ~/.zshrc ~/.config/starship.toml ~/.gitmux.conf
rm -rf ~/.config/kitty ~/.config/alacritty

# Remove the repo
rm -rf ~/trmnl
```

---

## License

MIT
