if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# LANG
# export LANG=ja_JP.UTF-8

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

# historical forward/backward search with linehead string
# Only works in an interactive mode
if [[ $- == *i* ]]; then
    bind '"\C-p": history-search-backward'
    bind '"\C-n": history-search-forward'
fi

# oh-my-zsh config
export ZSH_CUSTOM=$HOME/.zsh_custom

# Hide 'default interactive shell is now zsh'
export BASH_SILENCE_DEPRECATION_WARNING=1

# Launch `ssh-agent` by default
if [ -f ~/.ssh/id_ed25519 ]; then
  KEY_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}')
  if ! ssh-add -l 2>/dev/null | grep -q "$KEY_FINGERPRINT"; then
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  fi
fi

# PATH settings

# golang
[ -d /usr/local/go ] && export PATH=$PATH:/usr/local/go/bin
[ -d $HOME/.go ] && export GOPATH=$HOME/.go
[ -d $GOPATH ] && export PATH=$PATH:$GOPATH/bin

# ~/.local/bin
[ -d $HOME/.local/bin ] && export PATH=$HOME/.local/bin:$PATH

# homebrew on Apple Silicon Macs
[ -d /opt/homebrew/bin ] && export PATH=/opt/homebrew/bin:$PATH

# mise
[ -f $HOME/.local/bin/mise ] && eval "$(mise activate bash)"

PS1='\[\e[1;37m\]\u@\h \[\e[1;36m\]\w \$\[\e[0m\] '

