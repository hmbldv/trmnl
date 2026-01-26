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

# Check if we have non-interactive sudo access
has_sudo() {
    sudo -n true 2>/dev/null
}

# Detect if running in a virtual machine
detect_vm() {
    IS_VM=false
    VM_TYPE=""

    case "$(uname -s)" in
        Darwin)
            # Check for Parallels
            if system_profiler SPHardwareDataType 2>/dev/null | grep -qi "Parallels"; then
                IS_VM=true
                VM_TYPE="Parallels"
            # Check for VMware
            elif system_profiler SPHardwareDataType 2>/dev/null | grep -qi "VMware"; then
                IS_VM=true
                VM_TYPE="VMware"
            # Check for VirtualBox
            elif system_profiler SPHardwareDataType 2>/dev/null | grep -qi "VirtualBox"; then
                IS_VM=true
                VM_TYPE="VirtualBox"
            # Check model identifier for common VM patterns
            elif system_profiler SPHardwareDataType 2>/dev/null | grep -i "Model Identifier" | grep -qiE "(parallels|vmware|virtualbox)"; then
                IS_VM=true
                VM_TYPE="Unknown VM"
            fi
            ;;
        Linux)
            # Check systemd-detect-virt
            if command -v systemd-detect-virt &>/dev/null; then
                local virt_type
                # Note: systemd-detect-virt returns exit code 1 when not virtualized
                virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
                if [[ "$virt_type" != "none" && -n "$virt_type" ]]; then
                    IS_VM=true
                    VM_TYPE="$virt_type"
                fi
            # Fallback: check DMI
            elif [[ -f /sys/class/dmi/id/product_name ]]; then
                local product
                product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
                if echo "$product" | grep -qiE "(virtualbox|vmware|parallels|qemu|kvm|xen|hyper-v)"; then
                    IS_VM=true
                    VM_TYPE="$product"
                fi
            fi
            ;;
    esac
}

# Detect if running over SSH (headless/remote session)
detect_ssh() {
    IS_SSH=false

    # Check for SSH environment variables
    if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
        IS_SSH=true
    # Check if stdin is not a terminal (could indicate remote/automated)
    elif [[ ! -t 0 ]]; then
        IS_SSH=true
    fi
}

# Check if display/GUI is available
has_display() {
    case "$(uname -s)" in
        Darwin)
            # On macOS, check if we can access the window server
            if [[ -n "$DISPLAY" ]] || system_profiler SPDisplaysDataType &>/dev/null; then
                return 0
            fi
            ;;
        Linux)
            # Check for display
            if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Prompt user to select terminal mode
select_terminal_mode() {
    TERMINAL_MODE="kitty"  # Default

    echo ""
    echo "================================"
    echo "  Terminal Selection"
    echo "================================"
    echo ""

    # Show environment warnings
    if [[ "$IS_VM" == "true" ]]; then
        warn "Virtual machine detected: $VM_TYPE"
        echo "      Kitty requires OpenGL 3.3 which may not work in VMs."
        echo ""
    fi

    if [[ "$IS_SSH" == "true" ]]; then
        warn "SSH/remote session detected"
        echo "      Kitty requires direct display access and won't work over SSH."
        echo ""
    fi

    echo "Choose your terminal emulator:"
    echo ""
    echo "  1) Kitty (GPU-accelerated, feature-rich)"
    echo "     - Requires OpenGL 3.3 and direct display access"
    echo "     - Best for: Native installs on physical machines"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo "     ${YELLOW}⚠ May not work in your current environment${NC}"
    fi
    echo ""
    echo "  2) Native Terminal (Terminal.app on macOS, system default on Linux)"
    echo "     - Works everywhere including VMs and SSH"
    echo "     - Best for: VMs, remote servers, compatibility"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo "     ${GREEN}✓ Recommended for your environment${NC}"
    fi
    echo ""

    # Default recommendation based on environment
    local default_choice="1"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        default_choice="2"
    fi

    while true; do
        read -p "Select terminal [1/2] (default: $default_choice): " choice
        choice="${choice:-$default_choice}"

        case "$choice" in
            1)
                TERMINAL_MODE="kitty"
                if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
                    echo ""
                    warn "You selected Kitty in a potentially incompatible environment."
                    echo "      If Kitty fails to launch, you can re-run this installer"
                    echo "      and select option 2 (Native Terminal) instead."
                    echo ""
                    read -p "Continue with Kitty? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                info "Selected: Kitty terminal"
                break
                ;;
            2)
                TERMINAL_MODE="native"
                info "Selected: Native terminal"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Check for required dependencies
check_dependencies() {
    local missing=()
    for dep in curl git unzip; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

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
            if has_sudo; then
                sudo apt update && sudo apt install -y zsh-syntax-highlighting zsh-autosuggestions 2>/dev/null || {
                    info "Package install failed, installing manually..."
                    mkdir -p ~/.zsh
                    if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                    fi
                    if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                        git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                    fi
                }
            else
                info "No sudo access, installing zsh plugins to ~/.zsh..."
                mkdir -p ~/.zsh
                if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                fi
                if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                    git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                fi
            fi
            ;;
        arch)
            sudo pacman -S --noconfirm zsh-syntax-highlighting zsh-autosuggestions
            ;;
        fedora)
            if has_sudo; then
                sudo dnf install -y zsh-syntax-highlighting zsh-autosuggestions 2>/dev/null || {
                    info "Package install failed, installing manually..."
                    mkdir -p ~/.zsh
                    if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                    fi
                    if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                        git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                    fi
                }
            else
                info "No sudo access, installing zsh plugins to ~/.zsh..."
                mkdir -p ~/.zsh
                if [[ ! -d ~/.zsh/zsh-syntax-highlighting ]]; then
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
                fi
                if [[ ! -d ~/.zsh/zsh-autosuggestions ]]; then
                    git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions
                fi
            fi
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

    # Remove existing themes symlink/dir to prevent recursion
    if [ -L "$KITTY_CONFIG/themes" ]; then
        rm "$KITTY_CONFIG/themes"
    elif [ -d "$KITTY_CONFIG/themes" ]; then
        warn "Backing up existing themes directory to themes.bak"
        mv "$KITTY_CONFIG/themes" "$KITTY_CONFIG/themes.bak"
    fi
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

# Symlink gitmux config
link_gitmux() {
    info "Linking gitmux config..."

    if [ -f "$HOME/.gitmux.conf" ] && [ ! -L "$HOME/.gitmux.conf" ]; then
        warn "Backing up existing .gitmux.conf to .gitmux.conf.bak"
        mv "$HOME/.gitmux.conf" "$HOME/.gitmux.conf.bak"
    fi

    ln -sf "$REPO_DIR/gitmux/gitmux.conf" "$HOME/.gitmux.conf"

    info "gitmux config linked"
}

# Print mode-specific post-install instructions
print_instructions() {
    echo ""
    info "Installation complete!"
    echo ""

    if [[ "$TERMINAL_MODE" == "kitty" ]]; then
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
    else
        echo "Next steps:"
        echo "  1. Restart your terminal (or run: source ~/.zshrc)"
        echo "  2. Start tmux and press 'Ctrl+A I' to install plugins (if needed)"
        echo ""

        if [[ "$OS" == "macos" ]]; then
            echo "  ${YELLOW}Font configuration (required for icons):${NC}"
            echo "  3. Open Terminal → Settings → Profiles → [Your Profile] → Text"
            echo "  4. Click 'Change...' next to Font"
            echo "  5. Select 'JetBrainsMono Nerd Font Mono' at size 12"
        else
            echo "  ${YELLOW}Font configuration:${NC}"
            echo "  Ensure your terminal emulator uses 'JetBrainsMono Nerd Font'"
            echo "  for proper icon rendering in the prompt and tmux status bar."
        fi
        echo ""
        echo "Quick tips:"
        echo "  - Reload zsh: source ~/.zshrc"
        echo "  - Reload tmux: Ctrl+A r"
    fi
}

# Main
main() {
    echo "================================"
    echo "  ktty-trmnl-tmx installer"
    echo "================================"
    echo ""

    check_dependencies
    detect_os

    # Detect environment for terminal selection
    detect_vm
    detect_ssh

    # Let user choose terminal mode
    select_terminal_mode

    echo ""
    echo "================================"
    echo "  Installing components"
    echo "================================"
    echo ""

    # Core tools - warn but continue if any fail
    install_font || warn "Font installation failed (continuing)"

    # Only install Kitty if user selected it
    if [[ "$TERMINAL_MODE" == "kitty" ]]; then
        install_kitty || warn "Kitty installation failed (continuing)"
    else
        info "Skipping Kitty installation (Native Terminal mode)"
    fi

    install_tmux || warn "tmux installation failed (continuing)"
    install_tpm || warn "TPM installation failed (continuing)"
    install_gitmux || warn "gitmux installation failed (continuing)"
    install_starship || warn "Starship installation failed (continuing)"
    install_zsh || warn "zsh installation failed (continuing)"
    install_zsh_plugins || warn "zsh plugins installation failed (continuing)"

    # Symlinks - these are the critical part
    if [[ "$TERMINAL_MODE" == "kitty" ]]; then
        link_kitty
    fi
    link_tmux
    link_zsh
    link_starship
    link_gitmux

    install_tmux_plugins || warn "tmux plugins installation failed (run 'prefix + I' manually)"

    print_instructions
}

main "$@"
