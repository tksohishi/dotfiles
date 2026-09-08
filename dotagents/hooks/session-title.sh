#!/bin/bash
# SessionStart: name the session after the launch directory (like /rename),
# so /resume and the tab show "life", "dotfiles", "degen" instead of a
# generated title. Skips when the user already named the session (--name,
# /rename) and on clear/compact, where Claude Code ignores sessionTitle anyway.
input=$(cat)
source=$(jq -r '.source // empty' <<< "$input")
case "$source" in startup|resume|fork) ;; *) exit 0 ;; esac
[ -z "$(jq -r '.session_title // empty' <<< "$input")" ] || exit 0
dir=$(jq -r '.cwd // empty' <<< "$input")
[ -n "$dir" ] || dir=$PWD
name=$(basename "$dir")
name="${name#.}"
[ -n "$name" ] || exit 0
jq -cn --arg t "$name" '{hookSpecificOutput:{hookEventName:"SessionStart",sessionTitle:$t}}'
