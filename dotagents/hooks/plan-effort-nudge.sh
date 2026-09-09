#!/bin/bash
# UserPromptSubmit: in plan mode at low effort, remind the user once per
# session that a higher effort may be worth it for planning. Effort is fixed
# per process and no hook can change it; this only surfaces the choice.
#
# UserPromptSubmit input has no effort field. Read the live level from
# CLAUDE_EFFORT when present, else the session baseline that
# effort-baseline.sh records on the first tool call.
input=$(cat)
sid=$(jq -r '.session_id // empty' <<< "$input")
effort=$(jq -r '.effort.level // empty' <<< "$input")
[ -n "$effort" ] || effort=${CLAUDE_EFFORT:-}
if [ -z "$effort" ] && [ -n "$sid" ]; then
  base="${TMPDIR:-/tmp}/claude-effort-baseline-$sid"
  [ -f "$base" ] && effort=$(cat "$base")
fi
[ "$(jq -r '.permission_mode // empty' <<< "$input")" = "plan" ] || exit 0
[ "$effort" = "low" ] || exit 0
if [ -n "$sid" ]; then
  mark="${TMPDIR:-/tmp}/claude-plan-effort-nudge-$sid"
  [ -e "$mark" ] && exit 0
  : > "$mark"
fi
printf '{"systemMessage":"Plan mode at low effort. Consider a higher effort level for planning if the problem warrants it (/effort medium|high). Reset it before approving the plan; ExitPlanMode is blocked while effort differs from the session baseline."}\n'
