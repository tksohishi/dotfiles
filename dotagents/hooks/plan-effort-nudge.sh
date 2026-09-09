#!/bin/bash
# UserPromptSubmit: in plan mode at low effort, remind the user (once per
# session) that a higher effort may be worth it for planning. Effort is fixed
# per process and no hook can change it, so this only surfaces the choice.
input=$(cat)
[ "$(jq -r '.permission_mode // empty' <<< "$input")" = "plan" ] || exit 0
effort=$(jq -r '.effort.level // empty' <<< "$input")
[ -n "$effort" ] || effort=${CLAUDE_EFFORT:-}
[ "$effort" = "low" ] || exit 0
sid=$(jq -r '.session_id // empty' <<< "$input")
if [ -n "$sid" ]; then
  mark="${TMPDIR:-/tmp}/claude-plan-effort-nudge-$sid"
  [ -e "$mark" ] && exit 0
  : > "$mark"
fi
printf '{"systemMessage":"Plan mode at low effort. Consider a higher effort level for planning if the problem warrants it (/effort medium|high)."}\n'
