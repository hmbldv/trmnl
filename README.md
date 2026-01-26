# ktty-trmnl-tmx

Portable terminal configuration for Kitty + tmux + zsh. Drop-in setup for new machines across macOS and Linux.

## What's Included

- **Kitty** - GPU-accelerated terminal emulator
- **tmux** - Terminal multiplexer for session persistence
- **zsh** - Shell configuration with plugins
- **Starship** - Cross-shell prompt
- **JetBrainsMono Nerd Font** - Coding font with ligatures and icons

## Quick Start

```bash
git clone https://github.com/hmbldv/ktty-trmnl-tmx.git
cd ktty-trmnl-tmx
./install.sh
```

The installer will:
1. Detect your OS (macOS, Debian/Ubuntu, Fedora, Arch)
2. Install JetBrainsMono Nerd Font
3. Install Kitty, tmux, Starship, and zsh plugins
4. Symlink all configs to the correct locations

## Structure

```
ktty-trmnl-tmx/
├── install.sh              # Bootstrap script
├── kitty/
│   ├── kitty.conf          # Main Kitty config
│   └── themes/
│       ├── spacedust.conf  # Active theme
│       └── earthsong.conf
├── tmux/
│   └── tmux.conf           # tmux config
└── zsh/
    ├── zshrc               # Main zsh config
    ├── aliases.zsh         # Shared aliases
    └── starship.toml       # Starship prompt config
```

## Config Locations (After Install)

| Config | Location |
|--------|----------|
| Kitty | `~/.config/kitty/kitty.conf` |
| tmux | `~/.tmux.conf` |
| zsh | `~/.zshrc` |
| Starship | `~/.config/starship.toml` |
| Fonts | System font directory |

## Kitty Shortcuts

| Action | Shortcut |
|--------|----------|
| New tab | `Ctrl+Shift+T` |
| Close tab | `Ctrl+Shift+W` |
| Next/Prev tab | `Ctrl+Shift+Right/Left` |
| Go to tab N | `Ctrl+Shift+[1-5]` |
| Vertical split | `Ctrl+Shift+\` |
| Horizontal split | `Ctrl+Shift+-` |
| Navigate splits | `Ctrl+Shift+H/J/K/L` |
| Zoom pane (stack) | `Ctrl+Shift+Z` |
| Next layout | `Ctrl+Shift+.` |
| Reload config | `Ctrl+Shift+F5` |
| Increase font | `Ctrl+Shift+=` |
| Decrease font | `Ctrl+Shift+-` |
| Clear terminal | `Cmd+K` (macOS) |

## tmux Shortcuts

| Action | Shortcut |
|--------|----------|
| Prefix | `Ctrl+A` |
| Vertical split | `Prefix + \|` |
| Horizontal split | `Prefix + -` |
| Navigate panes | `Prefix + H/J/K/L` |
| New window | `Prefix + C` |
| Next/Prev window | `Prefix + N/P` |
| Reload config | `Prefix + R` |

## Kitty Kittens (Built-in Tools)

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

## Shell Aliases

```bash
# Navigation
..          # cd ..
...         # cd ../..

# Kitty
s           # kitty +kitten ssh
icat        # kitty +kitten icat
kdiff       # kitty +kitten diff

# Git
gs          # git status
ga          # git add
gc          # git commit
gp          # git push
gl          # git pull
glog        # git log --oneline --graph

# Misc
reload      # source ~/.zshrc
path        # echo $PATH (one per line)
```

## Platform Detection

The zsh config automatically detects your OS and:
- Sources plugins from the correct paths (Homebrew on Mac, system paths on Linux)
- Sets the appropriate Starship host icon ( for macOS,  for Linux)

## Adding a New Theme

1. Add theme file to `kitty/themes/`
2. Update the colors in `kitty.conf` or use include:
   ```conf
   include themes/your-theme.conf
   ```
3. Reload: `Ctrl+Shift+F5`

Or use the built-in theme kitten:
```bash
kitty +kitten themes
```

## Supported Platforms

| Platform | Package Manager | Status |
|----------|-----------------|--------|
| macOS | Homebrew | ✓ |
| Ubuntu/Debian | apt | ✓ |
| Fedora | dnf | ✓ |
| Arch | pacman | ✓ |
| Windows | - | Not supported (use WSL) |

## Manual Installation

If you prefer not to run the install script:

```bash
# macOS
brew install --cask kitty font-jetbrains-mono-nerd-font
brew install tmux starship zsh-syntax-highlighting zsh-autosuggestions

# Debian/Ubuntu
sudo apt install kitty tmux zsh-syntax-highlighting zsh-autosuggestions
curl -sS https://starship.rs/install.sh | sh
# Font: download from https://github.com/ryanoasis/nerd-fonts/releases

# Symlink configs
ln -sf $(pwd)/kitty/kitty.conf ~/.config/kitty/kitty.conf
ln -sf $(pwd)/kitty/themes ~/.config/kitty/themes
ln -sf $(pwd)/tmux/tmux.conf ~/.tmux.conf
ln -sf $(pwd)/zsh/zshrc ~/.zshrc
ln -sf $(pwd)/zsh/starship.toml ~/.config/starship.toml
```

## Updating

```bash
cd ktty-trmnl-tmx
git pull
# Configs are symlinked, changes apply immediately
# Reload Kitty: Ctrl+Shift+F5
# Reload zsh: source ~/.zshrc
# Reload tmux: Prefix + R
```

## License

MIT
