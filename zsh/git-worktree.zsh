# =============================================================================
# Git Worktree Helpers (bare clone + worktree workflow)
# =============================================================================

REPOS_DIR="$HOME/Repositories"

# Clone a GitHub repo as bare + worktree into owner-namespaced structure
# Usage: gwt-clone <github-url-or-owner/repo>
gwt-clone() {
    local input="$1"
    local url owner repo

    # Handle shorthand: owner/repo → full URL
    if [[ "$input" =~ ^[^/]+/[^/]+$ ]]; then
        url="git@github.com:${input}.git"
    else
        url="$input"
    fi

    # Extract owner and repo from URL
    if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        owner="${match[1]}"
        repo="${match[2]}"
    else
        echo "Error: Could not parse GitHub URL: $url" >&2
        return 1
    fi

    local target="$REPOS_DIR/$owner/$repo"

    if [[ -d "$target" ]]; then
        echo "Error: $target already exists" >&2
        return 1
    fi

    mkdir -p "$target"
    echo "Cloning $owner/$repo as bare + worktree..."

    git clone --bare "$url" "$target/.bare" || return 1
    git -C "$target/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git -C "$target/.bare" fetch origin
    echo "gitdir: ./.bare" > "$target/.git"

    local default_branch
    default_branch=$(git -C "$target/.bare" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    default_branch="${default_branch:-main}"

    git -C "$target" worktree add "$default_branch" "$default_branch"
    echo "Done! Worktree at: $target/$default_branch"
}

# Create a new worktree (run from inside any repo worktree or repo root)
# Usage: gwt-add <branch-name> [base-branch]
gwt-add() {
    local branch="$1"
    local base="${2:-main}"
    if [[ -z "$branch" ]]; then
        echo "Usage: gwt-add <branch-name> [base-branch]" >&2
        return 1
    fi
    git worktree add "../$branch" -b "$branch" "$base"
    echo "Worktree created: ../$branch"
}

# Remove a worktree and prune
# Usage: gwt-rm <branch-name>
gwt-rm() {
    local branch="$1"
    if [[ -z "$branch" ]]; then
        echo "Usage: gwt-rm <branch-name>" >&2
        return 1
    fi
    git worktree remove "../$branch" && git worktree prune
}

# List worktrees
alias gwt-ls="git worktree list"
