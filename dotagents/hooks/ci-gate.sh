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

# Second line of defense behind ci-gate-record.sh: a marker for a repo with no
# push/pull_request-triggered workflow can never resolve, so drop it instead of
# blocking. Same parser as ci-gate-record.sh; keep them in sync.
has_push_workflow() {
  local f
  for f in "$1"/.github/workflows/*.yml "$1"/.github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    awk '
      /^[[:space:]]*#/ { next }
      /^("on"|'"'"'on'"'"'|on)[[:space:]]*:/ {
        inon = 1; v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
        if (v ~ /(^|[^a-z_])(push|pull_request)([^a-z_]|$)/) { found = 1; exit }
        next
      }
      inon && /^[^[:space:]#]/ { inon = 0 }
      inon && /^[[:space:]]+(-[[:space:]]*)?(push|pull_request)[[:space:]]*(:|$)/ { found = 1; exit }
      END { exit !found }
    ' "$f" && return 0
  done
  return 1
}

if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
  if ! has_push_workflow "$cwd"; then rm -f "$marker"; exit 0; fi
  block "CI gate: no Actions runs found yet for pushed commit $short. Wait ~15s (sleep is blocked; use gh run list --commit $sha) and end the turn again."
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
