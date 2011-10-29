if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
export EDITOR=vim

# alias
if [ -f $HOME/.alias ]; then
    source $HOME/.alias
fi

# oh-my-zsh config
export ZSH_CUSTOM=$HOME/.zsh_custom
