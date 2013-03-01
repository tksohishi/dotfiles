if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
export EDITOR=vim

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

# historical backward search with linehead string
bind '"\C-p": history-search-backward'
# historical forward search with linehead string
bind '"\C-n": history-search-forward'

# oh-my-zsh config
export ZSH_CUSTOM=$HOME/.zsh_custom
