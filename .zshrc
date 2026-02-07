# .zshrc - minimal standalone zsh config

# Environment
export EDITOR=vim
export REPORTTIME=10
export LANG=ja_JP.UTF-8

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt share_history

# Completion
autoload -U compinit
compinit

# Options
setopt auto_cd
setopt auto_pushd
setopt correct
setopt list_packed
setopt nolistbeep

# Keybindings (emacs mode)
bindkey -e
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end

# Source shared configs
[ -f ~/.alias ] && source ~/.alias
[ -f ~/.alias.local ] && source ~/.alias.local
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# PATH
[ -d /opt/homebrew/bin ] && export PATH=/opt/homebrew/bin:$PATH
[ -d $HOME/.local/bin ] && export PATH=$HOME/.local/bin:$PATH
[ -d /usr/local/go ] && export PATH=$PATH:/usr/local/go/bin
[ -d $HOME/.go ] && export GOPATH=$HOME/.go && export PATH=$PATH:$GOPATH/bin
[ -d $HOME/.cargo/bin ] && export PATH=$PATH:$HOME/.cargo/bin

# ssh-agent (macOS keychain)
if [ -f ~/.ssh/id_ed25519 ]; then
    KEY_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}')
    if ! ssh-add -l 2>/dev/null | grep -q "$KEY_FINGERPRINT"; then
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    fi
fi

# Tool initialization
command -v mise >/dev/null && eval "$(mise activate zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
