#!/bin/bash
# UserPromptSubmit: record the session's baseline effort (first level seen)
# for plan-exit-effort-gate.sh, and in plan mode at low effort remind the
# user once per session that a higher effort may be worth it for planning.
# Effort is fixed per process and no hook can change it; this only surfaces
# the choice.
input=$(cat)
effort=$(jq -r '.effort.level // empty' <<< "$input")
[ -n "$effort" ] || effort=${CLAUDE_EFFORT:-}
sid=$(jq -r '.session_id // empty' <<< "$input")
if [ -n "$sid" ] && [ -n "$effort" ]; then
  base="${TMPDIR:-/tmp}/claude-effort-baseline-$sid"
  [ -e "$base" ] || printf '%s' "$effort" > "$base"
fi
[ "$(jq -r '.permission_mode // empty' <<< "$input")" = "plan" ] || exit 0
[ "$effort" = "low" ] || exit 0
if [ -n "$sid" ]; then
  mark="${TMPDIR:-/tmp}/claude-plan-effort-nudge-$sid"
  [ -e "$mark" ] && exit 0
  : > "$mark"
fi
printf '{"systemMessage":"Plan mode at low effort. Consider a higher effort level for planning if the problem warrants it (/effort medium|high). Reset it before approving the plan; ExitPlanMode is blocked while effort differs from the session baseline."}\n'
