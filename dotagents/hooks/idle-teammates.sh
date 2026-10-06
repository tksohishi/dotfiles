#!/usr/bin/env bash
# Stop hook: block ending the turn while a spawned teammate is idle (it has
# reported and sits registered) or looks stuck; a teammate still working is
# left alone. Membership is the session's team config
# (~/.claude/teams/session-<id8>/config.json, the authoritative list; TaskList
# does not show pre-compaction teammates). Working vs idle is read from the
# member's own transcript (~/.claude/projects/*/<session>/subagents/agent-<name>-*.jsonl):
# a last line that is a tool call or a tool result means it is mid-task; a last
# line that is assistant text alone means it has reported. A transcript not
# written for STUCK_MIN minutes is flagged as possibly stuck either way.
set -eu

STUCK_MIN=${IDLE_TEAMMATES_STUCK_MIN:-30}

input=$(cat)

# Loop guard: a block re-fires Stop with stop_hook_active=true
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0

sid=$(echo "$input" | jq -r '.session_id')
sid8=$(echo "$sid" | cut -c1-8)
cfg="${CLAUDE_TEAMS_DIR:-$HOME/.claude/teams}/session-$sid8/config.json"
[ -f "$cfg" ] || exit 0

names=$(jq -r '.members[].name | select(. != "team-lead")' "$cfg")
[ -z "$names" ] && exit 0

now=$(date +%s)
idle=""; stuck=""
for name in $names; do
  # newest transcript for this member (a re-spawn under the same name leaves older ones)
  # the file is agent-<agentId>-<hash>.jsonl and the agentId carries a prefix letter before the name
  t=$(ls -t "$HOME"/.claude/projects/*/"$sid"/subagents/agent-*"$name"-*.jsonl 2>/dev/null | head -1 || true)
  if [ -z "$t" ]; then idle="$idle $name"; continue; fi
  age=$(( (now - $(stat -f %m "$t")) / 60 ))
  if [ "$age" -ge "$STUCK_MIN" ]; then stuck="$stuck $name(${age}m)"; continue; fi
  # the last message line (attachments and other bookkeeping lines skipped): assistant text with no tool_use means it
  # has reported and waits; a tool call or a tool result means it is mid-task
  last=$(tail -30 "$t" | jq -rs '[.[] | select(.type == "assistant" or .type == "user")] | last | if . == null then "working" elif .type == "assistant" and ([.message.content[]? | select(.type == "tool_use")] | length) == 0 then "idle" else "working" end' 2>/dev/null || echo working)
  [ "$last" = "idle" ] && idle="$idle $name"
done

[ -z "$idle" ] && [ -z "$stuck" ] && exit 0

reason=""
[ -n "$idle" ] && reason="Idle teammates (reported, still registered):${idle}. TaskStop each one whose report is integrated."
[ -n "$stuck" ] && reason="${reason:+$reason }Teammates with no transcript write for ${STUCK_MIN}+ min:${stuck}. Check whether they are stuck (a pending permission, a hung command) before ending the turn."
jq -n --arg reason "$reason Then end the turn." '{ decision: "block", reason: $reason }'
