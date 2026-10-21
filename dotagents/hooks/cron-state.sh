#!/bin/bash
# PostToolUse(CronCreate|CronDelete): record the session's cron jobs so
# statusline.sh can show the next fire; the statusline JSON has no such field.
# File per job: "<first fire> <recurring> <created> <offset> <minutes...>".
# humanSchedule can be prose ("Every 30 minutes"), so parse tool_input.cron.
input=$(cat)
session=$(jq -r '.session_id // empty' <<< "$input")
[ -n "$session" ] || exit 0
dir="$HOME/.claude/state/crons/$session"

if [ "$(jq -r '.tool_name' <<< "$input")" = "CronDelete" ]; then
  id=$(jq -r '.tool_input.id // empty' <<< "$input")
  [ -n "$id" ] && rm -f "$dir/$id"
  exit 0
fi

id=$(jq -r '.tool_response.id // empty' <<< "$input")
fire=$(jq -r '.tool_response.nextFireAt // empty | . / 1000 | floor' <<< "$input")
[ -n "$id" ] && [ -n "$fire" ] || exit 0
recurring=$(jq -r '.tool_input.recurring != false' <<< "$input")
read -r min rest <<< "$(jq -r '.tool_input.cron // empty' <<< "$input")"

minutes=()
if [ "$recurring" = "true" ] && [ "$rest" = "* * * *" ]; then
  IFS=, read -ra items <<< "$min"
  for item in "${items[@]}"; do
    step=1
    [[ $item == */* ]] && step=${item#*/} && item=${item%/*}
    case $item in
      '*') lo=0 hi=59 ;;
      *-*) lo=${item%-*} hi=${item#*-} ;;
      *) lo=$item hi=$item; [ "$step" -gt 1 ] && hi=59 ;;
    esac
    [[ $lo$hi$step =~ ^[0-9]+$ ]] && [ "$step" -gt 0 ] || { minutes=(); break; }
    for ((m = lo; m <= hi; m += step)); do minutes+=("$m"); done
  done
fi

offset=0
if [ ${#minutes[@]} -gt 0 ]; then
  in_hour=$(( fire % 3600 ))
  best=3600
  for m in "${minutes[@]}"; do
    d=$(( (in_hour - m * 60 + 3600) % 3600 ))
    [ "$d" -lt "$best" ] && best=$d
  done
  offset=$best
fi

mkdir -p "$dir"
echo "$fire $recurring $(date +%s) $offset ${minutes[*]}" > "$dir/$id"
