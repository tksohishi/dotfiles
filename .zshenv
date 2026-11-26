# Read by every zsh, including `ssh host cmd`, which skips .zshrc.
# Keep this to what non-interactive commands need; the interactive PATH lives in .zshrc.
typeset -U path
[ -d /opt/homebrew/bin ] && path=(/opt/homebrew/bin $path)
[ -d $HOME/.local/bin ] && path=($HOME/.local/bin $path)
