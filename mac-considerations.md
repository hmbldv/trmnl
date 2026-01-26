# macOS Testing Considerations

Pre-testing checklist for ktty-trmnl-tmx on macOS after Linux testing (commit `9aea973`).

---

## Changes Made - Impact on macOS

| Change | macOS Impact | Risk |
|--------|--------------|------|
| `tmux default-command "zsh"` | Fine - zsh is default on macOS | Low |
| `Macos = "\uf302"` (Apple icon) | Needs testing - Unicode escape for Nerd Font | Medium |
| Font size 12 | Same on both platforms | Low |
| Leading space in prompt | Same on both platforms | Low |

---

## Potential macOS Issues to Watch

### 1. Homebrew Font Cask Name

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

The cask name may have changed. Verify this installs correctly.

**To test:**
```bash
brew search jetbrains-mono-nerd
```

### 2. Intel vs Apple Silicon Plugin Paths

The zshrc only checks `/opt/homebrew/share/` (Apple Silicon):

```bash
# Line 52-57 in zshrc
if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
```

**Missing:** Intel Macs use `/usr/local/share/` - these paths aren't checked.

**To check architecture:**
```bash
uname -m
# arm64 = Apple Silicon (uses /opt/homebrew/)
# x86_64 = Intel (uses /usr/local/)
```

### 3. Apple Icon Rendering

The `\uf302` codepoint (nf-linux-apple) should render as the Apple logo but needs verification with JetBrainsMono Nerd Font on macOS.

**To test:**
```bash
starship module os
```

Should display the Apple icon (), not a box or question mark.

---

## Pre-Testing Checklist

- [ ] Verify `brew install --cask font-jetbrains-mono-nerd-font` works
- [ ] Check architecture (`uname -m`) - Apple Silicon or Intel
- [ ] If Intel Mac, add `/usr/local/share/` plugin paths to zshrc before testing
- [ ] Run install script
- [ ] Verify Apple icon renders in prompt (`starship module os`)
- [ ] Verify zsh plugins load (syntax highlighting, autosuggestions)
- [ ] Verify tmux uses zsh (`ps -p $$ -o comm=` inside tmux)
- [ ] Verify font renders correctly (Nerd Font icons in prompt and tmux status bar)

---

## Files to Potentially Update

If Intel Mac support needed:

**zsh/zshrc** - Add Intel Homebrew paths:
```bash
# Intel Mac paths
if [[ -f /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
if [[ -f /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
```
