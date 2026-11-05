#!/usr/bin/env bash
# Stop hook, Claude desktop app only: block ending the turn when the final
# assistant message hands the user more than one shell code block. The user
# runs each one and pastes or reports its result, and the next step depends on
# it, so the reply offers one command and waits.
set -eu
[ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-desktop" ] || exit 0
input=$(cat)
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

last=$(jq -rs 'map(select(.type == "assistant") | .message.content
  | if type == "array" then map(select(.type == "text") | .text) | last // empty
    elif type == "string" then . else empty end)
  | map(select(. != "")) | last // empty' "$transcript" 2>/dev/null || true)
[ -n "$last" ] || exit 0

n=$(printf '%s\n' "$last" | grep -Ec '^[[:space:]]*```(bash|sh|shell|zsh|console)[[:space:]]*$' || true)
if [ "${n:-0}" -ge 2 ]; then
  jq -n --arg n "$n" '{decision:"block", reason:("The reply hands the user " + $n + " shell code blocks. In the Claude app give one command at a time: the user runs it, reports the result, and the next command follows from that. Rewrite the reply with only the first command and say what comes after it in words.")}'
fi
exit 0
