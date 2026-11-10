#!/bin/bash
# PostToolUse(ScheduleWakeup): record the session's next self-paced /loop
# wakeup so statusline.sh can show it; the statusline JSON has no such field.
# Wakeups cleared with Esc or dropped by /clear leave files behind; each run
# prunes the ones whose time has passed.
input=$(cat)
session=$(jq -r '.session_id // empty' <<< "$input")
[ -n "$session" ] || exit 0
dir="$HOME/.claude/state/wakeups"
mkdir -p "$dir"
now=$(date +%s)
for f in "$dir"/*; do
  [ -f "$f" ] || continue
  [ "$(cat "$f")" -le "$now" ] 2>/dev/null && rm -f "$f"
done
if [ "$(jq -r '.tool_input.stop // false' <<< "$input")" = "true" ]; then
  rm -f "$dir/$session"
  exit 0
fi
delay=$(jq -r '.tool_input.delaySeconds // empty' <<< "$input")
[ -n "$delay" ] || exit 0
echo $(( now + ${delay%.*} )) > "$dir/$session"
