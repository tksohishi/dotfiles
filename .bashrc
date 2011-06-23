if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# LANG
export LANG=ja_JP.UTF-8

# alias
if [ -f $HOME/.alias ]; then
    source $HOME/.alias
fi
