#!/bin/bash
# ktty-trmnl-tmx install script
# Installs kitty, tmux, zsh plugins, starship, fonts, and symlinks configs

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KITTY_CONFIG="$HOME/.config/kitty"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
TMUX_CONFIG="$HOME/.tmux.conf"
ZSHRC="$HOME/.zshrc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin)
            OS="macos"
            ;;
        Linux)
            if [ -f /etc/debian_version ]; then
                OS="debian"
            elif [ -f /etc/fedora-release ]; then
                OS="fedora"
            elif [ -f /etc/arch-release ]; then
                OS="arch"
            else
                OS="linux"
            fi
            ;;
        *)
            error "Unsupported operating system"
            ;;
    esac
    info "Detected OS: $OS"
}

# Install JetBrainsMono Nerd Font
install_font() {
    info "Checking for JetBrainsMono Nerd Font..."

    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        info "JetBrainsMono Nerd Font already installed"
        return
    fi

    info "Installing JetBrainsMono Nerd Font..."

    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                brew install --cask font-jetbrains-mono-nerd-font
            else
                error "Homebrew not found. Install from https://brew.sh"
            fi
            ;;
        debian)
            FONT_DIR="$HOME/.local/share/fonts"
            mkdir -p "$FONT_DIR"
            FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
            TEMP_DIR=$(mktemp -d)
            info "Downloading font..."
            curl -fsSL "$FONT_URL" -o "$TEMP_DIR/JetBrainsMono.zip"
            info "Extracting font..."
            unzip -q "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
            info "Updating font cache..."
            fc-cache -f
            rm -rf "$TEMP_DIR"
            ;;
        arch)
            sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd
            ;;
        fedora)
            FONT_DIR="$HOME/.local/share/fonts"
            mkdir -p "$FONT_DIR"
            FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
            TEMP_DIR=$(mktemp -d)
            curl -fsSL "$FONT_URL" -o "$TEMP_DIR/JetBrainsMono.zip"
            unzip -q "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
            fc-cache -f
            rm -rf "$TEMP_DIR"
            ;;
        *)
            warn "Could not auto-install font. Install JetBrainsMono Nerd Font manually."
            ;;
    esac
}

# Install Kitty
install_kitty() {
    info "Checking for Kitty..."

    if command -v kitty &>/dev/null; then
        info "Kitty already installed: $(kitty --version)"
        return
    fi

    info "Installing Kitty..."

    case "$OS" in
        macos)
            brew install --cask kitty
            ;;
        debian|fedora|linux)
            curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
            mkdir -p "$HOME/.local/bin"
            ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/"
            ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"
            ;;
        arch)
            sudo pacman -S --noconfirm kitty
            ;;
    esac
}

# Install tmux
install_tmux() {
    info "Checking for tmux..."

    if command -v tmux &>/dev/null; then
        info "tmux already installed: $(tmux -V)"
        return
    fi

    info "Installing tmux..."

    case "$OS" in
        macos)
            brew install tmux
            ;;
        debian)
            sudo apt update && sudo apt install -y tmux
            ;;
        arch)
            sudo pacman -S --noconfirm tmux
            ;;
        fedora)
            sudo dnf install -y tmux
            ;;
    esac
}

# Install Starship prompt
install_starship() {
    info "Checking for Starship..."

    if command -v starship &>/dev/null; then
        info "Starship already installed: $(starship --version)"
        return
    fi

    info "Installing Starship..."

    case "$OS" in
        macos)
            brew install starship
            ;;
        *)
            curl -sS https://starship.rs/install.sh | sh -s -- -y
            ;;
    esac
}

# Install zsh plugins
install_zsh_plugins() {
    info "Checking for zsh plugins..."

    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                brew install zsh-syntax-highlighting zsh-autosuggestions 2>/dev/null || true
                info "zsh plugins installed via Homebrew"
            fi
            ;;
        debian)
            sudo apt update && sudo apt install -y zsh-syntax-highlighting zsh-autosuggestions 2>/dev/null || {
                info "Installing zsh plugins manually..."
                mkdir -p ~/.zsh
                if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                fi
                if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                    git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                fi
            }
            ;;
        arch)
            sudo pacman -S --noconfirm zsh-syntax-highlighting zsh-autosuggestions
            ;;
        fedora)
            sudo dnf install -y zsh-syntax-highlighting zsh-autosuggestions 2>/dev/null || {
                info "Installing zsh plugins manually..."
                mkdir -p ~/.zsh
                if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                fi
                if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                    git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                fi
            }
            ;;
    esac
}

# Install TPM (Tmux Plugin Manager)
install_tpm() {
    info "Checking for TPM..."

    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        info "TPM already installed"
        return
    fi

    info "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

# Install gitmux (git status for tmux)
install_gitmux() {
    info "Checking for gitmux..."

    if command -v gitmux &>/dev/null; then
        info "gitmux already installed"
        return
    fi

    info "Installing gitmux..."

    case "$OS" in
        macos)
            brew install gitmux
            ;;
        *)
            # Download binary for Linux
            GITMUX_VERSION="v0.11.5"
            ARCH=$(uname -m)
            case "$ARCH" in
                x86_64)  GITMUX_ARCH="amd64" ;;
                aarch64) GITMUX_ARCH="arm64" ;;
                armv7l)  GITMUX_ARCH="armv6" ;;
                *)
                    warn "Unsupported architecture for gitmux: $ARCH"
                    return
                    ;;
            esac
            GITMUX_URL="https://github.com/arl/gitmux/releases/download/${GITMUX_VERSION}/gitmux_${GITMUX_VERSION}_linux_${GITMUX_ARCH}.tar.gz"
            TEMP_DIR=$(mktemp -d)
            curl -fsSL "$GITMUX_URL" -o "$TEMP_DIR/gitmux.tar.gz"
            tar -xzf "$TEMP_DIR/gitmux.tar.gz" -C "$TEMP_DIR"
            mkdir -p "$HOME/.local/bin"
            mv "$TEMP_DIR/gitmux" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/gitmux"
            rm -rf "$TEMP_DIR"
            ;;
    esac
}

# Install tmux plugins via TPM
install_tmux_plugins() {
    info "Installing tmux plugins..."

    if [[ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
        "$HOME/.tmux/plugins/tpm/bin/install_plugins"
        info "tmux plugins installed"
    else
        warn "TPM not found. Run 'prefix + I' in tmux to install plugins."
    fi
}

# Symlink kitty config
link_kitty() {
    info "Linking Kitty config..."

    mkdir -p "$KITTY_CONFIG"

    if [ -f "$KITTY_CONFIG/kitty.conf" ] && [ ! -L "$KITTY_CONFIG/kitty.conf" ]; then
        warn "Backing up existing kitty.conf to kitty.conf.bak"
        mv "$KITTY_CONFIG/kitty.conf" "$KITTY_CONFIG/kitty.conf.bak"
    fi

    ln -sf "$REPO_DIR/kitty/kitty.conf" "$KITTY_CONFIG/kitty.conf"
    ln -sf "$REPO_DIR/kitty/themes" "$KITTY_CONFIG/themes"

    # Copy app icon (symlink doesn't work for icons)
    if [ -f "$REPO_DIR/kitty/kitty.app.png" ]; then
        cp "$REPO_DIR/kitty/kitty.app.png" "$KITTY_CONFIG/kitty.app.png"
        info "Kitty icon installed"
    fi

    info "Kitty config linked"
}

# Symlink tmux config
link_tmux() {
    info "Linking tmux config..."

    if [ -f "$TMUX_CONFIG" ] && [ ! -L "$TMUX_CONFIG" ]; then
        warn "Backing up existing .tmux.conf to .tmux.conf.bak"
        mv "$TMUX_CONFIG" "$TMUX_CONFIG.bak"
    fi

    ln -sf "$REPO_DIR/tmux/tmux.conf" "$TMUX_CONFIG"

    info "tmux config linked"
}

# Symlink zsh config
link_zsh() {
    info "Linking zsh config..."

    if [ -f "$ZSHRC" ] && [ ! -L "$ZSHRC" ]; then
        warn "Backing up existing .zshrc to .zshrc.bak"
        mv "$ZSHRC" "$ZSHRC.bak"
    fi

    ln -sf "$REPO_DIR/zsh/zshrc" "$ZSHRC"

    info "zsh config linked"
}

# Symlink starship config
link_starship() {
    info "Linking Starship config..."

    mkdir -p "$(dirname "$STARSHIP_CONFIG")"

    if [ -f "$STARSHIP_CONFIG" ] && [ ! -L "$STARSHIP_CONFIG" ]; then
        warn "Backing up existing starship.toml to starship.toml.bak"
        mv "$STARSHIP_CONFIG" "$STARSHIP_CONFIG.bak"
    fi

    ln -sf "$REPO_DIR/zsh/starship.toml" "$STARSHIP_CONFIG"

    info "Starship config linked"
}

# Main
main() {
    echo "================================"
    echo "  ktty-trmnl-tmx installer"
    echo "================================"
    echo ""

    detect_os
    install_font
    install_kitty
    install_tmux
    install_tpm
    install_gitmux
    install_starship
    install_zsh_plugins
    link_kitty
    link_tmux
    link_zsh
    link_starship
    install_tmux_plugins

    echo ""
    info "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal (or run: source ~/.zshrc)"
    echo "  2. Reload Kitty config: Ctrl+Shift+F5"
    echo "  3. Start tmux and press 'Ctrl+A I' to install plugins (if needed)"
    echo ""
    echo "Quick tips:"
    echo "  - SSH with Kitty features: kitty +kitten ssh hostname"
    echo "  - View images: kitty +kitten icat image.png"
    echo "  - Reload zsh: source ~/.zshrc"
    echo "  - Reload tmux: Ctrl+A r"
}

main "$@"
