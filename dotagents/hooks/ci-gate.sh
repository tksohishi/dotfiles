#!/usr/bin/env bash
# Stop hook: after a push recorded by ci-gate-record.sh, block ending the turn
# until every Actions run for that SHA has completed. Green clears the marker
# silently; red blocks once with an explicit "report it red" instruction and
# then clears, so a failure can be relayed without looping. In-progress runs
# block repeatedly (bounded) so the agent waits with `gh run watch` instead of
# reporting from a background task's exit status.
set -eu
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')
marker="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}/$sid.json"
[ -f "$marker" ] || exit 0

cwd=$(jq -r '.cwd' "$marker"); sha=$(jq -r '.sha' "$marker"); blocks=$(jq -r '.blocks' "$marker")
if [ "$blocks" -ge 12 ]; then rm -f "$marker"; exit 0; fi
jq -c '.blocks += 1' "$marker" > "$marker.tmp" && mv "$marker.tmp" "$marker"

runs=$(cd "$cwd" && gh run list --commit "$sha" --json databaseId,workflowName,status,conclusion 2>/dev/null || echo '[]')
short=${sha:0:7}
block() { jq -n --arg r "$1" '{decision:"block", reason:$r}'; exit 0; }

if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
  block "CI gate: no Actions runs found yet for pushed commit $short. Wait ~15s (sleep is blocked; use gh run list --commit $sha) and end the turn again. If this repo has no workflow for this branch, say so explicitly."
fi
pending=$(echo "$runs" | jq -r '[.[] | select(.status != "completed")] | map("\(.workflowName) (\(.databaseId))") | join(", ")')
if [ -n "$pending" ]; then
  ids=$(echo "$runs" | jq -r '[.[] | select(.status != "completed") | .databaseId] | join(" ")')
  block "CI gate: runs still in progress for $short: $pending. Run in the FOREGROUND, one per id, and read each exit code: gh run watch <id> --exit-status (ids: $ids). Then end the turn again."
fi
red=$(echo "$runs" | jq -r '[.[] | select(.conclusion != "success")] | map("\(.workflowName) (\(.databaseId)): \(.conclusion)") | join(", ")')
rm -f "$marker"
if [ -n "$red" ]; then
  block "CI gate: runs for $short did NOT all pass: $red. Tell the user CI is RED (do not say green), show the failing step via gh run view <id> --log-failed, and either fix it or state plainly that it is unfixed."
fi
exit 0
