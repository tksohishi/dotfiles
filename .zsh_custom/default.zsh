export TEST=1

# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
export EDITOR=vim

# mine
if [ -f $HOME/.zshrc.mine ]; then
   source $HOME/.zshrc.mine
fi

# alias
if [ -f $HOME/.alias ]; then
    source $HOME/.alias
fi

