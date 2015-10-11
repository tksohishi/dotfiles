# custom global zsh config file {{{

# functions {{{
init_rbenv() {
	eval "$(rbenv init - zsh)"
	_set_current_rbenv_version
}

init_rubies() {
	source "$HOME/.rubies/src/rubies.sh"
	_set_current_rubies_version
}

_set_current_rbenv_version() {
	export CURRENT_RUBY_VERSION="$(rbenv version-name)"
}

_set_current_rubies_version() {
	export CURRENT_RUBY_VERSION="$(rubies version)"
}

# automating 'bundle exec' {{{
# ref: https://github.com/gma/bundler-exec
rbenv_installed() {
	which rbenv > /dev/null 2>&1
}

is_in_house_bundle_exists() {
	[ -f "$(pwd)/bundle.rb" ] && return 0 || return 1
}

bundler_installed() {
	if rbenv_installed; then
		rbenv which bundle > /dev/null 2>&1
	else
		which bundle > /dev/null 2>&1
	fi
}

within_bundler_project() {
	local dir="$(pwd)"
	while [ "$(dirname $dir)" != "/" ]; do
		[ -f "$dir/Gemfile" ] && return
		dir="$(dirname $dir)"
	done
	false
}

# colored echo output
# http://d.hatena.ne.jp/daijiroc/20090207/1233980551
run_with_bundler() {
	if is_in_house_bundle_exists; then
		#echo -e "run\e[36m ./bundle.rb exec $@ \e[m"
		./bundle.rb exec "$@"
	elif bundler_installed && within_bundler_project; then
		#echo "run\e[36m bundle exec $@ \e[m"
		bundle exec "$@"
	else
		"$@"
	fi
}

BUNDLED_COMMANDS=(cap capfify chef cucumber foreman guard haml hayaku heroku html2haml knife mustache pry racksh rackup rails rake rake2thor rspec ruby \
sass sass-convert script/console script/server sequel serve shotgun spec spork thin thor tilt tt turn twurl unicorn unicorn_rails)

for CMD in $BUNDLED_COMMANDS; do
	if [[ $CMD != "bundle" && $CMD != "gem" ]]; then
		alias $CMD="run_with_bundler $CMD"
	fi
done
# }}}

# override cd
cd() {
	builtin cd "$@"
	local result=$?
	rbenv_installed && _set_current_rbenv_version
	return $result
}

# }}}

# default {{{

# local zshrc
if [ -f $HOME/.zshrc.local ]; then
	source $HOME/.zshrc.local
fi

# alias
if [ -f $HOME/.alias ]; then
	source $HOME/.alias
fi

# local alias
if [ -f $HOME/.alias.local ]; then
	source $HOME/.alias.local
fi

# }}}

# correct {{{
unsetopt correct_all
# }}}

# history {{{
# historical backward/forward search with linehead string binded to ^P/^N
#
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end

bindkey "\\en" history-beginning-search-forward-end
# }}}

# rbenv {{{
init_rbenv
# }}}

# rubies {{{
#init_rubies
# }}}

# rprompt {{{
setopt transient_rprompt
RPROMPT="${RPROMPT} %{$fg[red]%}\${CURRENT_RUBY_VERSION}%{$reset_color%}"
# }}}

# java {{{
if [ -x /usr/libexec/java_home ]; then
	export JAVA_HOME=`/usr/libexec/java_home`
fi

# java options
export ANT_OPTS=-Xmx2048m
export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=256m"
export JAVA_TOOL_OPTIONS="-Dfile.encoding=utf8"
# }}}

# GOPATH {{{
[ -d $HOME/dev/goes ] && export GOPATH=$HOME/dev/goes
# }}}

# PATH {{{
# local binary
# node.js and npm
[ -d /usr/local/share/npm/bin ] && export PATH=/usr/local/share/npm/bin:$PATH
[ -d /usr/local/lib/node ] && export NODE_PATH=/usr/local/lib/node_modules

# ~/local/bin
[ -d $HOME/local/bin ] && export PATH=$HOME/local/bin:$PATH

# GO
[ -d $HOME/dev/goes ] && export PATH=$PATH:$GOPATH/bin
# }}}

# virtualenv {{{
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/dev/pythons
[ -x /usr/local/bin/virtualenvwrapper.sh ] && source /usr/local/bin/virtualenvwrapper.sh
# }}}

# zsh-notify {{{
source $HOME/dev/zsh-notify/notify.plugin.zsh
# }}}

# peco {{{
# search history
function peco-select-history() {
  local tac
  if which tac > /dev/null; then
    tac="tac"
  else
    tac="tail -r"
  fi
  BUFFER=$(\history -n 1 | eval $tac | peco)
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history
# }}}


# }}}

# vim:ts=4:sw=4:noexpandtab:foldmethod=marker:nowrap:ft=sh:
