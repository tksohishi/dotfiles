#!/bin/bash
# PostToolUse(ScheduleWakeup): record the session's next self-paced /loop
# wakeup so statusline.sh can show it; the statusline JSON has no such field.
# A wakeup cleared with Esc leaves the file behind; the statusline hides it
# once its time passes.
input=$(cat)
session=$(jq -r '.session_id // empty' <<< "$input")
[ -n "$session" ] || exit 0
dir="$HOME/.claude/state/wakeups"
mkdir -p "$dir"
if [ "$(jq -r '.tool_input.stop // false' <<< "$input")" = "true" ]; then
  rm -f "$dir/$session"
  exit 0
fi
delay=$(jq -r '.tool_input.delaySeconds // empty' <<< "$input")
[ -n "$delay" ] || exit 0
echo $(( $(date +%s) + ${delay%.*} )) > "$dir/$session"
