#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BREW=false

for arg in "$@"; do
    case "$arg" in
        --skip-brew) SKIP_BREW=true ;;
    esac
done

if [ "$SKIP_BREW" = false ]; then
    # Ask for sudo password upfront and keep session alive
    echo "You will be prompted for your macOS password for Homebrew setup."
    password_casks=$(grep '# Password prompt:' "$DOTFILES_DIR/Brewfile" | sed 's/.*cask "\([^"]*\)".*/\1/')
    if [ -n "$password_casks" ]; then
        echo "These casks will also prompt for your password during installation:"
        echo "$password_casks" | while read -r c; do echo "  - $c"; done
    fi
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Install all packages, apps, and App Store apps (no upgrades)
    echo "Installing packages from Brewfile..."
    HOMEBREW_BUNDLE_FILE="$DOTFILES_DIR/Brewfile" brew bundle --no-upgrade
fi

# Symlink dotfiles
files=(
    .alias
    .vimrc
    .gitconfig
    .zshrc
    .gitignore_global
    .tmux.conf
    .config/starship.toml
    .config/ghostty/config
    .config/mise/config.toml
)

echo ""
echo "Symlinking dotfiles to $HOME:"
echo ""
printf "  %s\n" "${files[@]}"
echo ""
read -p "Proceed? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

for f in "${files[@]}"; do
    target="$HOME/$f"
    source="$DOTFILES_DIR/$f"

    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "Backing up $target to $target.bak"
        mv "$target" "$target.bak"
    fi

    ln -s "$source" "$target"
    echo "Linked $f"
done

# ── AI agent tool configs ─────────────────────────────────────
echo ""
echo "Installing AI agent tool configs..."

# Shared agent instructions -> ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md
mkdir -p "$HOME/.claude" "$HOME/.codex"
for pair in ".claude/CLAUDE.md" ".codex/AGENTS.md"; do
    target="$HOME/$pair"
    source="$DOTFILES_DIR/dotagents/AGENTS.md"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "Backing up $target to $target.bak"
        mv "$target" "$target.bak"
    fi
    ln -s "$source" "$target"
    echo "Linked dotagents/AGENTS.md -> ~/$pair"
done

# Claude Code settings
target="$HOME/.claude/settings.json"
source="$DOTFILES_DIR/dotclaude/settings.json"
if [ -L "$target" ]; then
    rm "$target"
elif [ -f "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotclaude/settings.json -> ~/.claude/settings.json"

# Codex config (merge, not symlink; Codex overwrites symlinks)
# https://github.com/openai/codex/issues/11061
codex_src="$DOTFILES_DIR/dotcodex/config.toml"
codex_dst="$HOME/.codex/config.toml"
codex_tmp="$(mktemp)"
cp "$codex_src" "$codex_tmp"
if [ -f "$codex_dst" ]; then
    projects="$(awk '
        BEGIN { p = 0 }
        /^\[projects\./ { p = 1; print; next }
        /^\[/ { p = 0 }
        { if (p) print }
    ' "$codex_dst")"
    if [ -n "$projects" ]; then
        printf '\n%s\n' "$projects" >> "$codex_tmp"
    fi
fi
if [ -f "$codex_dst" ] && diff -q "$codex_tmp" "$codex_dst" >/dev/null 2>&1; then
    echo "Skipped dotcodex/config.toml (unchanged)"
else
    if [ -f "$codex_dst" ] && [ ! -L "$codex_dst" ]; then
        cp "$codex_dst" "${codex_dst}.bak"
        echo "Backing up $codex_dst to ${codex_dst}.bak"
    fi
    cp "$codex_tmp" "$codex_dst"
    echo "Merged dotcodex/config.toml -> ~/.codex/config.toml"
fi
rm -f "$codex_tmp"

echo ""
echo "Done."

# Remind about apps that need manual installation
manual=$(grep '^# Manual install:' "$DOTFILES_DIR/Brewfile" | sed 's/^# Manual install: //')
if [ -n "$manual" ]; then
    echo ""
    echo "The following apps need manual installation:"
    echo "$manual" | while read -r app; do
        echo "  - $app"
    done
fi
