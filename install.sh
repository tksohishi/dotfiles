#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

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

echo "This will symlink the following files to $HOME:"
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
echo "Done. Install prerequisites with:"
echo "  brew install starship zoxide mise ghostty"
