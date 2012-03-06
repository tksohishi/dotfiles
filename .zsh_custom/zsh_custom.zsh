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

# automating 'bundle exec' {{{
# ref: https://github.com/gma/bundler-exec
bundler_installed()
{
	which bundle > /dev/null 2>&1
}

within_bundler_project()
{
	local dir="$(pwd)"
	while [ "$(dirname $dir)" != "/" ]; do
		[ -f "$dir/Gemfile" ] && return
		dir="$(dirname $dir)"
	done
	false
}

run_with_bundler()
{
	if bundler_installed && within_bundler_project; then
		bundle exec "$@"
	else
		"$@"
	fi
}

BUNDLED_COMMANDS="${BUNDLED_COMMANDS:-
cap
capify
cucumber
foreman
guard
haml
heroku
html2haml
rackup
rails
rake
rake2thor
rspec
ruby
sass
sass-convert
serve
shotgun
spec
spork
thin
thor
tilt
tt
turn
unicorn
unicorn_rails
}"

for CMD in $BUNDLED_COMMANDS; do
	if [[ $CMD != "bundle" && $CMD != "gem" ]]; then
		alias $CMD="run_with_bundler $CMD"
	fi
done
# }}}
# }}}

# default {{{
# LANG
export LANG=ja_JP.UTF-8

# EDITOR is vim
init_editor

# mine
if [ -f $HOME/.zshrc.mine ]; then
	source $HOME/.zshrc.mine
fi

# alias
if [ -f $HOME/.alias ]; then
	source $HOME/.alias
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
PERLBREW_ROOT=$HOME/.perl5/perlbrew
[ -d $PERLBREW_ROOT ] && source $PERLBREW_ROOT/etc/bashrc
# }}}

# rubies {{{
init_rubies
# }}}

# rprompt {{{
setopt transient_rprompt
RPROMPT="${RPROMPT} %{$fg[red]%}\${RUBIES_RUBY_NAME}%{$reset_color%}"
# }}}

# vim:ts=4:sw=4:noexpandtab:foldmethod=marker:nowrap:ft=sh:
