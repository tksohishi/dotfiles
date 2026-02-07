#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install all packages, apps, and App Store apps
echo "Installing packages from Brewfile..."
HOMEBREW_BUNDLE_FILE="$DOTFILES_DIR/Brewfile" brew bundle

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

echo ""
echo "Done."
