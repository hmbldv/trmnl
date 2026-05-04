#!/bin/bash
# trmnl install script
# Installs terminal emulators, tmux, zsh plugins, starship, fonts, CLI tools, and symlinks configs

set -eo pipefail
# Note: `set -u` is intentionally NOT set yet — adding it requires auditing every
# variable reference for unbound-default safety. Tracked as a follow-up.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KITTY_CONFIG="$HOME/.config/kitty"
ALACRITTY_CONFIG="$HOME/.config/alacritty"
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

# -----------------------------------------------------------------------------
# Pinned versions and SHA256 checksums for downloaded binary artifacts.
# To bump: change the version, re-run on a trusted machine, paste the new SHA.
# Verify upstream signatures or release notes before bumping production checksums.
# -----------------------------------------------------------------------------
NERD_FONT_VERSION="v3.4.0"
NERD_FONT_SHA256="76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c"

GITMUX_VERSION="v0.11.5"
# SHA256 per platform_arch tuple (linux_amd64, linux_arm64, macOS_amd64, macOS_arm64)
GITMUX_SHA256_linux_amd64="d46a10f5fe07ab5b8a902ac29c937e4d3c8d7f33ea30fa335d682601697b5a71"
GITMUX_SHA256_linux_arm64="89a03a76828267927d57904f0f716a9b9aad627d1697d5c0c883d60c09bb4ff6"
GITMUX_SHA256_macOS_amd64="0ff0b4c4e30ca0615fc0cd966b7bc3f10b6c02b8a3164802b94e621aa5aee698"
GITMUX_SHA256_macOS_arm64="89f0a88e1fbbd74d13dfbb92a5ccb2c3d5bc397546b8a4fb5372d98bacf79c0e"

# Expected GPG fingerprint for the eza apt signing key
# (https://github.com/eza-community/eza/blob/main/INSTALL.md)
EZA_GPG_FINGERPRINT="1548BC8A4B4D2688F9B0DAF7EC29E2090CE3FD43"

# -----------------------------------------------------------------------------
# Cleanup tracking — register temp dirs and they get rm -rf'd on EXIT.
# -----------------------------------------------------------------------------
TRMNL_TEMP_DIRS=()
trmnl_cleanup() {
    local d
    for d in "${TRMNL_TEMP_DIRS[@]}"; do
        [ -d "$d" ] && rm -rf "$d"
    done
}
trap trmnl_cleanup EXIT

# Create a temp dir tracked for cleanup on EXIT.
trmnl_mktemp() {
    local d
    d=$(mktemp -d)
    TRMNL_TEMP_DIRS+=("$d")
    echo "$d"
}

# Verify a file's SHA256 against an expected value. Hard-fails on mismatch.
verify_sha256() {
    local file="$1" expected="$2" actual
    if [ ! -f "$file" ]; then
        error "verify_sha256: file does not exist: $file"
    fi
    if command -v sha256sum &>/dev/null; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        error "Neither sha256sum nor shasum available; cannot verify $file"
    fi
    if [ "$actual" != "$expected" ]; then
        error "Checksum mismatch for $file
       expected: $expected
       actual:   $actual
       Refusing to install — file may be tampered or version drifted."
    fi
    info "Verified SHA256 for $(basename "$file")"
}

# Track which install steps failed so we can surface them at the end.
TRMNL_FAILED=()
record_failure() { TRMNL_FAILED+=("$1"); }

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
    # Refuse to prompt if stdin isn't a TTY — otherwise `read` consumes
    # whatever happens to be on stdin (including a piped script's own body)
    # and silently picks a mode the user didn't choose.
    if [[ ! -t 0 ]]; then
        error "Installer requires interactive stdin. Run from a terminal: ./install.sh"
    fi

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

    echo "Choose your setup:"
    echo ""
    echo "  1) Kitty       (GPU-accelerated, feature-rich)"
    echo "     - Requires OpenGL 3.3 and direct display access"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo -e "     ${YELLOW}⚠ May not work in your current environment${NC}"
    fi
    echo ""
    echo "  2) Alacritty   (GPU-accelerated, minimal config)"
    echo "     - Requires OpenGL 3.3 and direct display access"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo -e "     ${YELLOW}⚠ May not work in your current environment${NC}"
    fi
    echo ""
    echo "  3) Terminal only (shell, prompt, and tmux — no emulator)"
    echo "     - Works everywhere including VMs and SSH"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo -e "     ${GREEN}✓ Recommended for your environment${NC}"
    fi
    echo ""
    echo "  4) All of the above (Kitty + Alacritty + everything)"
    echo "     - Installs both terminal emulators plus all tools"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        echo -e "     ${YELLOW}⚠ Emulators may not work in your current environment${NC}"
    fi
    echo ""

    # Default recommendation based on environment
    local default_choice="1"
    if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
        default_choice="3"
    fi

    while true; do
        read -p "Select terminal [1/2/3/4] (default: $default_choice): " choice
        choice="${choice:-$default_choice}"

        case "$choice" in
            1)
                TERMINAL_MODE="kitty"
                if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
                    echo ""
                    warn "You selected Kitty in a potentially incompatible environment."
                    echo "      If Kitty fails to launch, you can re-run this installer"
                    echo "      and select option 3 (Terminal only) instead."
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
                TERMINAL_MODE="alacritty"
                if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
                    echo ""
                    warn "You selected Alacritty in a potentially incompatible environment."
                    echo "      If Alacritty fails to launch, you can re-run this installer"
                    echo "      and select option 3 (Terminal only) instead."
                    echo ""
                    read -p "Continue with Alacritty? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                info "Selected: Alacritty terminal"
                break
                ;;
            3)
                TERMINAL_MODE="native"
                info "Selected: Terminal only (no emulator)"
                break
                ;;
            4)
                TERMINAL_MODE="all"
                if [[ "$IS_VM" == "true" || "$IS_SSH" == "true" ]]; then
                    echo ""
                    warn "You selected All in a potentially incompatible environment."
                    echo "      Terminal emulators may not work, but shell/prompt/tmux will."
                    echo ""
                    read -p "Continue? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                info "Selected: All (Kitty + Alacritty + everything)"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, 3, or 4."
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
# Download, verify, and extract the JetBrainsMono Nerd Font zip safely.
# Pinned version + SHA256; extracts only *.ttf files into ~/.local/share/fonts
# to neutralize any zip-slip / unexpected-payload risk.
install_nerd_font_zip() {
    local font_dir="$HOME/.local/share/fonts"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"
    local temp_dir
    temp_dir=$(trmnl_mktemp)
    local zip="$temp_dir/JetBrainsMono.zip"

    mkdir -p "$font_dir"
    info "Downloading JetBrainsMono Nerd Font ${NERD_FONT_VERSION}..."
    curl -fsSL "$font_url" -o "$zip"
    verify_sha256 "$zip" "$NERD_FONT_SHA256"

    info "Extracting font (ttf only, into staging dir)..."
    local stage="$temp_dir/stage"
    mkdir -p "$stage"
    # Refuse archive entries that escape the staging dir; only extract .ttf files.
    unzip -qq -j "$zip" '*.ttf' -d "$stage"

    # Sanity check: stage must contain at least one regular file and nothing else.
    local f
    for f in "$stage"/*; do
        if [ ! -f "$f" ] || [ -L "$f" ]; then
            error "Unexpected entry in font archive after extraction: $f"
        fi
    done

    cp -f "$stage"/*.ttf "$font_dir/"
    info "Updating font cache..."
    fc-cache -f
}

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
        debian|fedora)
            install_nerd_font_zip
            ;;
        arch)
            sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd
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

# Install Alacritty
install_alacritty() {
    info "Checking for Alacritty..."

    if command -v alacritty &>/dev/null; then
        info "Alacritty already installed: $(alacritty --version)"
        return
    fi

    info "Installing Alacritty..."

    case "$OS" in
        macos)
            brew install --cask alacritty
            ;;
        debian)
            if sudo apt install -y alacritty 2>/dev/null; then
                info "Alacritty installed via apt"
            elif command -v cargo &>/dev/null; then
                info "apt package not available, building with cargo..."
                cargo install alacritty
            else
                warn "Alacritty not in apt repos and cargo not found. Install manually or install Rust first."
            fi
            ;;
        arch)
            sudo pacman -S --noconfirm alacritty
            ;;
        fedora)
            sudo dnf install -y alacritty
            ;;
        *)
            warn "Could not auto-install Alacritty. Install manually."
            ;;
    esac
}

# Install fzf
install_fzf() {
    info "Checking for fzf..."

    if command -v fzf &>/dev/null; then
        info "fzf already installed: $(fzf --version)"
        return
    fi

    info "Installing fzf..."

    case "$OS" in
        macos)
            brew install fzf
            ;;
        debian)
            sudo apt install -y fzf
            ;;
        arch)
            sudo pacman -S --noconfirm fzf
            ;;
        fedora)
            sudo dnf install -y fzf
            ;;
        *)
            warn "Could not auto-install fzf. Install manually."
            ;;
    esac
}

# Install zoxide
install_zoxide() {
    info "Checking for zoxide..."

    if command -v zoxide &>/dev/null; then
        info "zoxide already installed: $(zoxide --version)"
        return
    fi

    info "Installing zoxide..."

    case "$OS" in
        macos)
            brew install zoxide
            ;;
        debian)
            curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
            ;;
        arch)
            sudo pacman -S --noconfirm zoxide
            ;;
        fedora)
            sudo dnf install -y zoxide
            ;;
        *)
            warn "Could not auto-install zoxide. Install manually."
            ;;
    esac
}

# Install fastfetch
install_fastfetch() {
    info "Checking for fastfetch..."

    if command -v fastfetch &>/dev/null; then
        info "fastfetch already installed: $(fastfetch --version 2>/dev/null || echo 'unknown version')"
        return
    fi

    info "Installing fastfetch..."

    case "$OS" in
        macos)
            brew install fastfetch
            ;;
        debian)
            if ! sudo apt install -y fastfetch 2>/dev/null; then
                warn "fastfetch not available in apt repos. Install manually from https://github.com/fastfetch-cli/fastfetch"
            fi
            ;;
        arch)
            sudo pacman -S --noconfirm fastfetch
            ;;
        fedora)
            sudo dnf install -y fastfetch
            ;;
        *)
            warn "Could not auto-install fastfetch. Install manually."
            ;;
    esac
}

# Install fd
install_fd() {
    info "Checking for fd..."
    if command -v fd &>/dev/null || command -v fdfind &>/dev/null; then
        info "fd already installed"
        return
    fi
    info "Installing fd..."
    case "$OS" in
        macos)   brew install fd ;;
        debian)  sudo apt install -y fd-find ;;
        arch)    sudo pacman -S --noconfirm fd ;;
        fedora)  sudo dnf install -y fd-find ;;
        *)       warn "Could not auto-install fd." ;;
    esac
}

# Install bat
install_bat() {
    info "Checking for bat..."
    if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
        info "bat already installed"
        return
    fi
    info "Installing bat..."
    case "$OS" in
        macos)   brew install bat ;;
        debian)  sudo apt install -y bat ;;
        arch)    sudo pacman -S --noconfirm bat ;;
        fedora)  sudo dnf install -y bat ;;
        *)       warn "Could not auto-install bat." ;;
    esac
}

# Install delta
install_delta() {
    info "Checking for delta..."
    if command -v delta &>/dev/null; then
        info "delta already installed"
        return
    fi
    info "Installing delta..."
    case "$OS" in
        macos)   brew install git-delta ;;
        debian)  sudo apt install -y git-delta 2>/dev/null || warn "delta not in apt repos. Install from: https://github.com/dandavison/delta/releases" ;;
        arch)    sudo pacman -S --noconfirm git-delta ;;
        fedora)  sudo dnf install -y git-delta ;;
        *)       warn "Could not auto-install delta." ;;
    esac
}

# Install eza
install_eza() {
    info "Checking for eza..."
    if command -v eza &>/dev/null; then
        info "eza already installed"
        return
    fi
    info "Installing eza..."
    case "$OS" in
        macos)   brew install eza ;;
        debian)
            local key_tmp keyring_path actual_fpr
            key_tmp=$(trmnl_mktemp)
            info "Fetching eza apt signing key..."
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc -o "$key_tmp/deb.asc"

            keyring_path="$key_tmp/gierens.gpg"
            gpg --dearmor < "$key_tmp/deb.asc" > "$keyring_path"

            actual_fpr=$(gpg --show-keys --with-colons "$keyring_path" 2>/dev/null \
                | awk -F: '/^fpr:/ {print $10; exit}')
            if [ "$actual_fpr" != "$EZA_GPG_FINGERPRINT" ]; then
                error "eza GPG key fingerprint mismatch
       expected: $EZA_GPG_FINGERPRINT
       actual:   ${actual_fpr:-<none>}
       Refusing to add untrusted apt source."
            fi
            info "Verified eza GPG fingerprint."

            sudo mkdir -p /etc/apt/keyrings
            sudo install -m 0644 "$keyring_path" /etc/apt/keyrings/gierens.gpg
            # Use HTTPS transport in addition to apt's signature check (defense in depth).
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" \
                | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
            sudo apt update && sudo apt install -y eza
            ;;
        arch)    sudo pacman -S --noconfirm eza ;;
        fedora)  sudo dnf install -y eza ;;
        *)       warn "Could not auto-install eza." ;;
    esac
}

# Install direnv
install_direnv() {
    info "Checking for direnv..."
    if command -v direnv &>/dev/null; then
        info "direnv already installed"
        return
    fi
    info "Installing direnv..."
    case "$OS" in
        macos)   brew install direnv ;;
        debian)  sudo apt install -y direnv ;;
        arch)    sudo pacman -S --noconfirm direnv ;;
        fedora)  sudo dnf install -y direnv ;;
        *)       warn "Could not auto-install direnv." ;;
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
        debian|fedora)
            local pkg_cmd
            case "$OS" in
                debian) pkg_cmd="sudo apt update && sudo apt install -y zsh-syntax-highlighting zsh-autosuggestions" ;;
                fedora) pkg_cmd="sudo dnf install -y zsh-syntax-highlighting zsh-autosuggestions" ;;
            esac

            if has_sudo && eval "$pkg_cmd" 2>/dev/null; then
                info "zsh plugins installed via system package manager"
            else
                if has_sudo; then
                    info "Package install failed, falling back to pinned git clone..."
                else
                    warn "No passwordless sudo; falling back to pinned git clone in \$HOME/.zsh"
                fi
                mkdir -p "$HOME/.zsh"
                git_clone_pinned https://github.com/zsh-users/zsh-syntax-highlighting.git \
                    "$ZSH_SYNTAX_HIGHLIGHTING_TAG" "$HOME/.zsh/zsh-syntax-highlighting"
                git_clone_pinned https://github.com/zsh-users/zsh-autosuggestions.git \
                    "$ZSH_AUTOSUGGESTIONS_TAG" "$HOME/.zsh/zsh-autosuggestions"
            fi
            ;;
        arch)
            sudo pacman -S --noconfirm zsh-syntax-highlighting zsh-autosuggestions
            ;;
    esac
}

# Pinned upstream tags / commits for plugins we git-clone. Bump deliberately
# after reviewing the upstream changelog; tracking master/main pulls arbitrary
# new code into every shell or tmux startup.
ZSH_SYNTAX_HIGHLIGHTING_TAG="0.8.0"
ZSH_AUTOSUGGESTIONS_TAG="v0.7.1"
TPM_TAG="v3.1.0"

# git_clone_pinned <repo-url> <tag-or-branch> <dest>
# Shallow-clones a single tag/branch. Hard-fails on error (no silent skip).
git_clone_pinned() {
    local url="$1" ref="$2" dest="$3"
    [ -d "$dest" ] && return 0
    git clone --depth 1 --branch "$ref" "$url" "$dest" \
        || error "git clone of $url@$ref failed"
}

# Install TPM (Tmux Plugin Manager)
install_tpm() {
    info "Checking for TPM..."

    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        info "TPM already installed"
        return
    fi

    info "Installing TPM ${TPM_TAG}..."
    git_clone_pinned https://github.com/tmux-plugins/tpm "$TPM_TAG" "$HOME/.tmux/plugins/tpm"
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
            local arch tuple sha_var expected_sha url temp_dir
            arch=$(uname -m)
            case "$arch" in
                x86_64)  tuple="linux_amd64";  sha_var="GITMUX_SHA256_linux_amd64" ;;
                aarch64) tuple="linux_arm64";  sha_var="GITMUX_SHA256_linux_arm64" ;;
                *)
                    warn "Unsupported architecture for gitmux ($arch); skipping"
                    return
                    ;;
            esac
            expected_sha="${!sha_var}"
            url="https://github.com/arl/gitmux/releases/download/${GITMUX_VERSION}/gitmux_${GITMUX_VERSION}_${tuple}.tar.gz"

            temp_dir=$(trmnl_mktemp)
            info "Downloading gitmux ${GITMUX_VERSION} (${tuple})..."
            curl -fsSL "$url" -o "$temp_dir/gitmux.tar.gz"
            verify_sha256 "$temp_dir/gitmux.tar.gz" "$expected_sha"

            info "Extracting gitmux to staging dir..."
            local stage="$temp_dir/stage"
            mkdir -p "$stage"
            # --no-same-owner / --no-same-permissions defang ownership shenanigans.
            # Extract into stage, then validate exactly one regular file named "gitmux".
            tar -xzf "$temp_dir/gitmux.tar.gz" -C "$stage" --no-same-owner --no-same-permissions
            if [ ! -f "$stage/gitmux" ] || [ -L "$stage/gitmux" ]; then
                error "gitmux archive did not contain expected layout (missing or symlinked gitmux binary)"
            fi

            mkdir -p "$HOME/.local/bin"
            install -m 0755 "$stage/gitmux" "$HOME/.local/bin/gitmux"
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

# Move an existing real file or directory aside before symlinking.
# Backups get a unix-timestamp suffix so re-runs never clobber a previous
# backup (the docs previously claimed simple "*.bak" — that's now true plus
# unique-per-run).
backup_existing() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.bak.$(date +%s)"
        warn "Backing up existing $(basename "$target") to $(basename "$backup")"
        mv "$target" "$backup"
    fi
}

# Symlink kitty config
link_kitty() {
    info "Linking Kitty config..."

    mkdir -p "$KITTY_CONFIG"

    backup_existing "$KITTY_CONFIG/kitty.conf"
    ln -sf "$REPO_DIR/kitty/kitty.conf" "$KITTY_CONFIG/kitty.conf"

    # Remove existing themes symlink to prevent recursion; backup real dir.
    if [ -L "$KITTY_CONFIG/themes" ]; then
        rm "$KITTY_CONFIG/themes"
    else
        backup_existing "$KITTY_CONFIG/themes"
    fi
    ln -sf "$REPO_DIR/kitty/themes" "$KITTY_CONFIG/themes"

    # Copy app icon (symlink doesn't work for icons)
    if [ -f "$REPO_DIR/kitty/kitty.app.png" ]; then
        cp "$REPO_DIR/kitty/kitty.app.png" "$KITTY_CONFIG/kitty.app.png"
        info "Kitty icon installed"
    fi

    info "Kitty config linked"
}

# Symlink alacritty config
link_alacritty() {
    info "Linking Alacritty config..."

    mkdir -p "$ALACRITTY_CONFIG"

    backup_existing "$ALACRITTY_CONFIG/alacritty.toml"
    ln -sf "$REPO_DIR/alacritty/alacritty.toml" "$ALACRITTY_CONFIG/alacritty.toml"

    info "Alacritty config linked"
}

# Symlink tmux config
link_tmux() {
    info "Linking tmux config..."

    backup_existing "$TMUX_CONFIG"
    ln -sf "$REPO_DIR/tmux/tmux.conf" "$TMUX_CONFIG"

    info "tmux config linked"
}

# Symlink zsh config
link_zsh() {
    info "Linking zsh config..."

    backup_existing "$ZSHRC"
    ln -sf "$REPO_DIR/zsh/zshrc" "$ZSHRC"

    info "zsh config linked"
}

# Symlink starship config
link_starship() {
    info "Linking Starship config..."

    mkdir -p "$(dirname "$STARSHIP_CONFIG")"

    backup_existing "$STARSHIP_CONFIG"
    ln -sf "$REPO_DIR/zsh/starship.toml" "$STARSHIP_CONFIG"

    info "Starship config linked"
}

# Symlink gitmux config
link_gitmux() {
    info "Linking gitmux config..."

    backup_existing "$HOME/.gitmux.conf"
    ln -sf "$REPO_DIR/gitmux/gitmux.conf" "$HOME/.gitmux.conf"

    info "gitmux config linked"
}

# Prompt to change default shell to zsh
prompt_change_shell() {
    # Check if zsh is available
    if ! command -v zsh &>/dev/null; then
        warn "zsh not found, skipping shell change prompt"
        return
    fi

    # Check if already using zsh
    local current_shell
    current_shell=$(basename "$SHELL")
    if [[ "$current_shell" == "zsh" ]]; then
        info "Default shell is already zsh"
        return
    fi

    echo ""
    echo "================================"
    echo "  Default Shell"
    echo "================================"
    echo ""
    echo "Your current default shell is: $current_shell"
    echo "This configuration is designed for zsh."
    echo ""

    if [[ "$IS_SSH" == "true" ]]; then
        echo -e "${YELLOW}Note: You're connected via SSH. After changing your shell,"
        echo -e "      you'll need to reconnect for it to take effect.${NC}"
        echo ""
    fi

    read -p "Change default shell to zsh? [y/N]: " change_shell
    if [[ "$change_shell" =~ ^[Yy]$ ]]; then
        local zsh_path=""
        # Prefer well-known absolute paths over PATH lookup so a poisoned PATH
        # can't route us to an attacker-controlled shell.
        local candidate
        for candidate in /usr/bin/zsh /bin/zsh /usr/local/bin/zsh /opt/homebrew/bin/zsh; do
            if [ -x "$candidate" ]; then zsh_path="$candidate"; break; fi
        done
        # Fall back to PATH lookup only if no canonical install was found.
        [ -z "$zsh_path" ] && zsh_path=$(command -v zsh)

        if [ -z "$zsh_path" ]; then
            warn "Could not locate zsh; skipping chsh."
            return
        fi
        if [ -f /etc/shells ] && ! grep -qxF "$zsh_path" /etc/shells; then
            warn "$zsh_path is not listed in /etc/shells; refusing to chsh"
            return
        fi
        if chsh -s "$zsh_path"; then
            info "Default shell changed to zsh"
            if [[ "$IS_SSH" == "true" ]]; then
                echo ""
                echo -e "${GREEN}Reconnect to your SSH session to use zsh.${NC}"
            else
                echo ""
                echo "Restart your terminal or run 'zsh' to start using it."
            fi
        else
            warn "Failed to change shell. You can do it manually with: chsh -s $zsh_path"
        fi
    else
        info "Keeping $current_shell as default. Run 'zsh' to use the new config."
    fi
}

# Print mode-specific post-install instructions
print_instructions() {
    echo ""
    info "Installation complete!"
    echo ""

    if [[ "$TERMINAL_MODE" == "kitty" || "$TERMINAL_MODE" == "all" ]]; then
        echo "Kitty tips:"
        echo "  - Reload config: Ctrl+Shift+F5"
        echo "  - SSH with Kitty features: kitty +kitten ssh hostname"
        echo "  - View images: kitty +kitten icat image.png"
        echo ""
    fi

    if [[ "$TERMINAL_MODE" == "alacritty" || "$TERMINAL_MODE" == "all" ]]; then
        echo "Alacritty tips:"
        echo "  - Config is live-reloaded on save"
        echo "  - Config location: ~/.config/alacritty/alacritty.toml"
        echo ""
    fi

    echo "Next steps:"
    echo "  1. Restart your terminal (or run: source ~/.zshrc)"
    echo "  2. Start tmux and press 'Ctrl+A I' to install plugins (if needed)"
    echo ""

    if [[ "$TERMINAL_MODE" == "native" ]]; then
        if [[ "$OS" == "macos" ]]; then
            echo -e "  ${YELLOW}Font configuration (required for icons):${NC}"
            echo "  3. Open Terminal → Settings → Profiles → [Your Profile] → Text"
            echo "  4. Click 'Change...' next to Font"
            echo "  5. Select 'JetBrainsMono Nerd Font Mono' at size 12"
        else
            echo -e "  ${YELLOW}Font configuration:${NC}"
            echo "  Ensure your terminal emulator uses 'JetBrainsMono Nerd Font'"
            echo "  for proper icon rendering in the prompt and tmux status bar."
        fi
        echo ""
    fi

    echo "Quick tips:"
    echo "  - Reload zsh: source ~/.zshrc"
    echo "  - Reload tmux: Ctrl+A r"
}

# Main
main() {
    echo "================================"
    echo "  trmnl installer"
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

    # try_install <component> — runs an install fn; on failure, records it and
    # warns but lets us continue. Use ONLY for optional tools whose failure
    # doesn't constitute a security event. Anything that downloads + verifies +
    # executes (font, gitmux, eza apt key) hard-fails inside its own function
    # via `error` so the user notices a tampered artifact.
    try_install() {
        local fn="$1"
        if ! "$fn"; then
            warn "${fn} failed; continuing without it"
            record_failure "$fn"
        fi
    }

    # Core tools (always installed)
    try_install install_font
    try_install install_tmux
    try_install install_tpm
    try_install install_gitmux
    try_install install_starship
    try_install install_zsh
    try_install install_zsh_plugins
    try_install install_fzf
    try_install install_zoxide
    try_install install_fastfetch
    try_install install_fd
    try_install install_bat
    try_install install_delta
    try_install install_eza
    try_install install_direnv

    # Terminal emulator(s) based on selection
    if [[ "$TERMINAL_MODE" == "kitty" || "$TERMINAL_MODE" == "all" ]]; then
        try_install install_kitty
    fi
    if [[ "$TERMINAL_MODE" == "alacritty" || "$TERMINAL_MODE" == "all" ]]; then
        try_install install_alacritty
    fi

    # Symlinks
    if [[ "$TERMINAL_MODE" == "kitty" || "$TERMINAL_MODE" == "all" ]]; then
        link_kitty
    fi
    if [[ "$TERMINAL_MODE" == "alacritty" || "$TERMINAL_MODE" == "all" ]]; then
        link_alacritty
    fi
    link_tmux
    link_zsh
    link_starship
    link_gitmux

    install_tmux_plugins || { warn "tmux plugins installation failed (run 'prefix + I' manually)"; record_failure "install_tmux_plugins"; }

    # Offer to change default shell
    prompt_change_shell

    print_instructions

    # Surface anything that didn't install cleanly. Hard failures (checksum
    # mismatches, GPG fingerprint mismatches, etc.) already exited via `error`;
    # this lists the soft "tool not in your distro repos"-class failures.
    if [ ${#TRMNL_FAILED[@]} -gt 0 ]; then
        echo ""
        warn "Some components did not install cleanly:"
        for fn in "${TRMNL_FAILED[@]}"; do
            echo "        - ${fn}"
        done
        echo "      Review the log above before relying on this installation."
    fi
}

main "$@"
