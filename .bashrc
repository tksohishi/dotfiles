if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
export EDITOR=vim

# REPORTTIME
export REPORTTIME=10

# local bashrc
if [ -f $HOME/.bashrc.local ]; then
    source $HOME/.bashrc.local
fi

# alias
if [ -f $HOME/.alias ]; then
    source $HOME/.alias
fi

# local alias
if [ -f $HOME/.alias.local ]; then
    source $HOME/.alias.local
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# historical backward search with linehead string
bind '"\C-p": history-search-backward'
# historical forward search with linehead string
bind '"\C-n": history-search-forward'

# oh-my-zsh config
export ZSH_CUSTOM=$HOME/.zsh_custom

# Hide 'default interactive shell is now zsh'
export BASH_SILENCE_DEPRECATION_WARNING=1

# To launch `tmux` from bash if installed via homebrew
if [ -f /opt/homebrew/bin/tmux ]; then
    alias tmux=/opt/homebrew/bin/tmux
fi

# Launch `ssh-agent` by default
if [ -f ~/.ssh/id_ed25519 ]; then
  KEY_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}')
  if ! ssh-add -l 2>/dev/null | grep -q "$KEY_FINGERPRINT"; then
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  fi
fi
