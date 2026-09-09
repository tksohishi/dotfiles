#!/bin/bash
# PreToolUse(ExitPlanMode): a bumped effort would carry into execution and
# get saved to modelSettings for future launches. Deny plan approval while
# the live effort differs from the session baseline recorded by
# plan-effort-nudge.sh, so the user resets it first.
input=$(cat)
effort=$(jq -r '.effort.level // empty' <<< "$input")
[ -n "$effort" ] || effort=${CLAUDE_EFFORT:-}
sid=$(jq -r '.session_id // empty' <<< "$input")
[ -n "$sid" ] && [ -n "$effort" ] || exit 0
base="${TMPDIR:-/tmp}/claude-effort-baseline-$sid"
[ -f "$base" ] || exit 0
baseline=$(cat "$base")
[ "$effort" != "$baseline" ] || exit 0
# Deny once; the retry after the user has weighed in passes.
denied="${TMPDIR:-/tmp}/claude-effort-gate-denied-$sid"
if [ -e "$denied" ]; then rm -f "$denied"; exit 0; fi
: > "$denied"
jq -cn --arg e "$effort" --arg b "$baseline" '{
  hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
    permissionDecisionReason: ("Effort is \($e) but the session started at \($b); it would persist into execution and be saved for future launches. Stop and end the turn: tell the user to run /effort \($b), or to say keep. Only after the user replies call ExitPlanMode again; the next call passes.")},
  systemMessage: "Plan approval blocked: effort is \($e), session baseline \($b). Run /effort \($b) before approving, or tell Claude to keep it."
}'
