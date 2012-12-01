# custom global zsh config file

# functions {{{
# imported via functions in niw/profiles
# ref: https://github.com/niw/profiles/blob/master/functions
init_rubies() {
	if [ -s "$HOME/.rubies/src/rubies.sh" ]; then
		source "$HOME/.rubies/src/rubies.sh"
		enable_rubies_cd_hook
		return 0
	fi
	return 1
}

init_editor() {
	for i in vim vi; do
		if which "$i" 2>&1 1>/dev/null; then
			export EDITOR="$i"
			break
		fi
	done
}

init_rbenv() {
	eval "$(rbenv init -)"
	_set_current_rbenv_version
}

_set_current_rbenv_version() {
	export CURRENT_RBENV_VERSION="$(rbenv version-name)"
}

# automating 'bundle exec' {{{
# ref: https://github.com/gma/bundler-exec
rbenv_installed() {
	which rbenv > /dev/null 2>&1
}

rubies_installed() {
	which rubies > /dev/null 2>&1
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
		echo -e "run\e[36m ./bundle.rb exec $@ \e[m"
		./bundle.rb exec "$@"
	elif bundler_installed && within_bundler_project; then
		echo "run\e[36m bundle exec $@ \e[m"
		bundle exec "$@"
	else
		"$@"
	fi
}

BUNDLED_COMMANDS=(cap capfify cucumber foreman guard haml hayaku heroku html2haml mustache racksh rackup rails rake rake2thor rspec ruby \
sass sass-convert script/server sequel serve shotgun spec spork thin thor tilt tt turn unicorn unicorn_rails)

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
# shell
export SHELL=zsh

# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
init_editor

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

# path {{{
# local binary
[ -d $HOME/local/bin ] && export PATH=$HOME/local/bin:$PATH

# node.js and npm
[ -f /usr/local/share/npm/bin ] && export PATH=$PATH:/usr/local/share/npm/bin
[ -d /usr/local/lib/node ] && export NODE_PATH=/usr/local/lib/node_modules
# }}}

# perlbrew {{{
#PERLBREW_ROOT=$HOME/.perl5/perlbrew
#[ -d $PERLBREW_ROOT ] && source $PERLBREW_ROOT/etc/bashrc
# }}}

# rubies {{{
#init_rubies
# }}}

# rbenv {{{
init_rbenv
# }}}

# pythonbrew {{{
[[ -s $HOME/.pythonbrew/etc/bashrc ]] && source $HOME/.pythonbrew/etc/bashrc
# }}}

# rprompt {{{
setopt transient_rprompt
RPROMPT="${RPROMPT} %{$fg[red]%}\${CURRENT_RBENV_VERSION}%{$reset_color%}"
# }}}

# autojump {{{
case "${OSTYPE}" in
darwin*)
if [ -f `brew --prefix`/etc/autojump.sh ]; then
	. `brew --prefix`/etc/autojump.sh
fi
;
esac
# }}}

# java {{{
if [ -x /usr/libexec/java_home ]; then
	export JAVA_HOME=`/usr/libexec/java_home`
fi
# }}}

# vim:ts=4:sw=4:noexpandtab:foldmethod=marker:nowrap:ft=sh:
