#!/usr/bin/env bash
# Stop hook: block ending the turn while spawned teammates are still
# registered in the session's team config. Detection is a file read
# (~/.claude/teams/session-<id8>/config.json is the authoritative member
# list; TaskList does not show pre-compaction teammates), so idle agents
# can't silently pile up in the Agents panel again.
set -eu

input=$(cat)

# Loop guard: a block re-fires Stop with stop_hook_active=true
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0

sid8=$(echo "$input" | jq -r '.session_id' | cut -c1-8)
cfg="${CLAUDE_TEAMS_DIR:-$HOME/.claude/teams}/session-$sid8/config.json"
[ -f "$cfg" ] || exit 0

names=$(jq -r '.members[].name | select(. != "team-lead")' "$cfg" | paste -sd ' ' -)
[ -z "$names" ] && exit 0

jq -n --arg names "$names" '{
  decision: "block",
  reason: ("Resident teammates still registered: " + $names + ". TaskStop each one whose report is integrated; keep only agents still working (they exit the team when stopped). Then end the turn.")
}'
