# =============================================================================
# trmnl :: Shared Aliases
# =============================================================================

# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# -----------------------------------------------------------------------------
# Listing (eza with fallback)
# -----------------------------------------------------------------------------
if command -v eza &>/dev/null; then
    alias ls='eza'
    alias ll='eza -la --git'
    alias la='eza -a'
    alias l='eza -l --git'
    alias lt='eza -la --tree --level=2 --git'
else
    case "$(uname -s)" in
        Darwin) alias ls='ls -G' ;;
        *)      alias ls='ls --color=auto' ;;
    esac
    alias ll='ls -lah'
    alias la='ls -a'
    alias l='ls -l'
fi

# -----------------------------------------------------------------------------
# bat (syntax-highlighted cat)
# -----------------------------------------------------------------------------
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
elif command -v batcat &>/dev/null; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
fi

# -----------------------------------------------------------------------------
# fd (modern find)
# -----------------------------------------------------------------------------
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    alias fd='fdfind'
fi

# -----------------------------------------------------------------------------
# Safety
# -----------------------------------------------------------------------------
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# -----------------------------------------------------------------------------
# Grep
# -----------------------------------------------------------------------------
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# -----------------------------------------------------------------------------
# Kitty
# -----------------------------------------------------------------------------
alias s='kitty +kitten ssh'
alias icat='kitty +kitten icat'
alias kdiff='kitty +kitten diff'

# -----------------------------------------------------------------------------
# Git (basics)
# -----------------------------------------------------------------------------
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate -10'

# -----------------------------------------------------------------------------
# Misc
# -----------------------------------------------------------------------------
alias c='clear'
alias h='history'
alias path='echo $PATH | tr ":" "\n"'
alias reload='source ~/.zshrc'
