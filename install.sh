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

# Integrate Kitty with Linux desktop environment
integrate_kitty_desktop() {
    info "Setting up Kitty desktop integration..."

    KITTY_APP="$HOME/.local/kitty.app"
    DESKTOP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

    # Create directories
    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$ICON_DIR"

    # Copy and update kitty.desktop
    if [ -f "$KITTY_APP/share/applications/kitty.desktop" ]; then
        cp "$KITTY_APP/share/applications/kitty.desktop" "$DESKTOP_DIR/"
        sed -i "s|^Icon=.*|Icon=$KITTY_APP/share/icons/hicolor/256x256/apps/kitty.png|g" "$DESKTOP_DIR/kitty.desktop"
        sed -i "s|^Exec=.*|Exec=$KITTY_APP/bin/kitty|g" "$DESKTOP_DIR/kitty.desktop"
        info "kitty.desktop installed"
    fi

    # Copy and update kitty-open.desktop (file manager integration)
    if [ -f "$KITTY_APP/share/applications/kitty-open.desktop" ]; then
        cp "$KITTY_APP/share/applications/kitty-open.desktop" "$DESKTOP_DIR/"
        sed -i "s|^Icon=.*|Icon=$KITTY_APP/share/icons/hicolor/256x256/apps/kitty.png|g" "$DESKTOP_DIR/kitty-open.desktop"
        sed -i "s|^Exec=.*|Exec=$KITTY_APP/bin/kitty|g" "$DESKTOP_DIR/kitty-open.desktop"
        info "kitty-open.desktop installed"
    fi

    # Copy icon
    if [ -f "$KITTY_APP/share/icons/hicolor/256x256/apps/kitty.png" ]; then
        cp "$KITTY_APP/share/icons/hicolor/256x256/apps/kitty.png" "$ICON_DIR/"
        info "Kitty icon installed"
    fi

    # Update desktop database if available
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi

    info "Kitty desktop integration complete"
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
            # Desktop integration
            integrate_kitty_desktop
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
            mkdir -p "$HOME/.local/bin"
            curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
            ;;
    esac
}

# Install zsh
install_zsh() {
    info "Checking for zsh..."

    if command -v zsh &>/dev/null; then
        info "zsh already installed: $(zsh --version)"
        return
    fi

    info "Installing zsh..."

    case "$OS" in
        macos)
            # zsh is default on macOS
            ;;
        debian)
            sudo apt update && sudo apt install -y zsh
            ;;
        arch)
            sudo pacman -S --noconfirm zsh
            ;;
        fedora)
            sudo dnf install -y zsh
            ;;
        *)
            warn "Could not auto-install zsh. Install manually."
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

    # Core tools - warn but continue if any fail
    install_font || warn "Font installation failed (continuing)"
    install_kitty || warn "Kitty installation failed (continuing)"
    install_tmux || warn "tmux installation failed (continuing)"
    install_tpm || warn "TPM installation failed (continuing)"
    install_gitmux || warn "gitmux installation failed (continuing)"
    install_starship || warn "Starship installation failed (continuing)"
    install_zsh || warn "zsh installation failed (continuing)"
    install_zsh_plugins || warn "zsh plugins installation failed (continuing)"

    # Symlinks - these are the critical part
    link_kitty
    link_tmux
    link_zsh
    link_starship

    install_tmux_plugins || warn "tmux plugins installation failed (run 'prefix + I' manually)"

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
