# custom global zsh config file with oh-my-zsh

# local zshrc
[ -f $HOME/.zshrc.local ] && source $HOME/.zshrc.local

# alias
[ -f $HOME/.alias ] && source $HOME/.alias

# local alias
[ -f $HOME/.alias.local ] && source $HOME/.alias.local

# correct
unsetopt correct_all

# history
# historical backward/forward search with linehead string binded to ^P/^N
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end
bindkey "\\en" history-beginning-search-forward-end

# PATH

# golang
[ -d /usr/local/go ] && export PATH=$PATH:/usr/local/go/bin
[ -d $HOME/.go ] && export GOPATH=$HOME/.go
[ -d $GOPATH ] && export PATH=$PATH:$GOPATH/bin

# ~/.local/bin
[ -d $HOME/.local/bin ] && export PATH=$HOME/.local/bin:$PATH

# homebrew on Apple Silicon Macs
[ -d /opt/homebrew/bin ] && export PATH=/opt/homebrew/bin:$PATH

# mise
[ -f $HOME/.local/bin/mise ] && eval "$($HOME/.local/bin/mise activate zsh)"
