if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# alias
if [ -f $HOME/.alias ]; then
    source $HOME/.alias
fi
