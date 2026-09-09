#!/bin/bash
# PreToolUse (every tool): record the session's baseline effort, the first
# level seen, for plan-exit-effort-gate.sh and plan-effort-nudge.sh.
#
# This lives on PreToolUse because the hook input carries `effort.level` only
# for tool-use events; UserPromptSubmit input has no effort field and
# CLAUDE_EFFORT is not reliably in that hook's environment in interactive
# sessions, so recording there left the gate without a baseline.
# Cost: one jq per tool call, and a stat after the first write.
input=$(cat)
sid=$(jq -r '.session_id // empty' <<< "$input")
[ -n "$sid" ] || exit 0
base="${TMPDIR:-/tmp}/claude-effort-baseline-$sid"
[ -e "$base" ] && exit 0
effort=$(jq -r '.effort.level // empty' <<< "$input")
[ -n "$effort" ] || effort=${CLAUDE_EFFORT:-}
[ -n "$effort" ] || exit 0
printf '%s' "$effort" > "$base"
exit 0
