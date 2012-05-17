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

# oh-my-zsh config
export ZSH_CUSTOM=$HOME/.zsh_custom
