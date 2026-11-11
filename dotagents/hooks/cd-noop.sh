#!/bin/bash
# Pre-hook: block a leading `cd <dir>` (followed by &&, ; or a newline) when
# <dir> is already the working directory.
#
# Opus pins the directory defensively on every call, and once a few such
# commands sit in context it copies the pattern, reaching a third or more of
# all Bash calls. A deny teaches the session to stop; a cd to any other
# directory passes.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -z "$CMD" ] || [ -z "$CWD" ] && exit 0

RE='^[[:space:]]*(cd|pushd)[[:blank:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]&;|]+)[[:blank:]]*(&&|;|'$'\n'')'
[[ "$CMD" =~ $RE ]] || exit 0
TARGET=${BASH_REMATCH[2]}
TARGET=${TARGET#[\"\']}
TARGET=${TARGET%[\"\']}

case "$TARGET" in
  "~") TARGET=$HOME ;;
  "~/"*) TARGET=$HOME/${TARGET#\~/} ;;
  '$HOME') TARGET=$HOME ;;
  '$HOME/'*) TARGET=$HOME/${TARGET#\$HOME/} ;;
  '$PWD' | .) TARGET=$CWD ;;
  '$'*) exit 0 ;;
esac

HERE=$(cd "$CWD" 2>/dev/null && pwd -P) || exit 0
THERE=$(cd "$CWD" 2>/dev/null && cd "$TARGET" 2>/dev/null && pwd -P) || exit 0
[ "$HERE" = "$THERE" ] || exit 0

REASON="The shell is already in $CWD, so the leading cd is a no-op. Rerun the command without it, and leave it off later calls in this directory."
jq -n --arg r "$REASON" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
