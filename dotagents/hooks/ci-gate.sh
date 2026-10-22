#!/usr/bin/env bash
# Stop hook: after a push recorded by ci-gate-record.sh, refuse to end the turn
# until every Actions run for that SHA has completed. The hook does the waiting
# itself: it polls `gh run list` until the runs finish or CI_GATE_WAIT_MAX
# seconds pass, so the common case (CI finishes within a few minutes) ends the
# turn with no visible block. Green clears the marker silently; red blocks once
# with an explicit "report it red" instruction and then clears, so a failure can
# be relayed without looping. Runs still pending past the wait bound block
# (bounded by the retry count) so the agent waits with `gh run watch` instead
# of reporting from a background task's exit status.
set -eu
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id')
marker="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}/$sid.json"
[ -f "$marker" ] || exit 0

cwd=$(jq -r '.cwd' "$marker"); sha=$(jq -r '.sha' "$marker"); blocks=$(jq -r '.blocks' "$marker")
if [ "$blocks" -ge 12 ]; then rm -f "$marker"; exit 0; fi
jq -c '.blocks += 1' "$marker" > "$marker.tmp" && mv "$marker.tmp" "$marker"

short=${sha:0:7}
block() { jq -n --arg r "$1" '{decision:"block", reason:$r}'; exit 0; }
fetch_runs() { (cd "$cwd" && gh run list --commit "$sha" --json databaseId,workflowName,status,conclusion 2>/dev/null) || echo '[]'; }
pending_of() { echo "$1" | jq -r '[.[] | select(.status != "completed")] | map("\(.workflowName) (\(.databaseId))") | join(", ")'; }

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

runs=$(fetch_runs)
if [ "$(echo "$runs" | jq 'length')" = "0" ] && ! has_push_workflow "$cwd"; then rm -f "$marker"; exit 0; fi

# Poll until every run has completed (runs that have not appeared yet count as
# pending) or the wait bound is reached. The bound must stay under the hook's
# timeout in settings.json, or the harness kills the hook and nothing is checked.
deadline=$(( $(date +%s) + ${CI_GATE_WAIT_MAX:-480} ))
# No run CI_GATE_NORUN_MAX seconds after the push, or while githubstatus says Actions
# is not operational, ends the gate with one report: the agent cannot make GitHub create a run.
pushed_at=$(jq -r '.pushedAt // empty' "$marker"); pushed_at=${pushed_at:-$(stat -f %m "$marker")}
norun_deadline=$(( pushed_at + ${CI_GATE_NORUN_MAX:-120} ))
actions_status=$(curl -s -m 5 https://www.githubstatus.com/api/v2/components.json | jq -r '.components[] | select(.name=="Actions") | .status' 2>/dev/null || true)
while :; do
  [ "$(echo "$runs" | jq 'length')" != "0" ] && [ -z "$(pending_of "$runs")" ] && break
  [ "$(date +%s)" -ge "$deadline" ] && break
  if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
    [ "$(date +%s)" -ge "$norun_deadline" ] && break
    [ -n "$actions_status" ] && [ "$actions_status" != operational ] && break
  fi
  sleep "${CI_GATE_WAIT_INTERVAL:-15}"
  runs=$(fetch_runs)
done

if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
  rm -f "$marker"
  block "CI gate: GitHub created no Actions run for pushed commit $short in $(( $(date +%s) - pushed_at )) s (githubstatus Actions: ${actions_status:-unknown}). The gate will not wait again for this SHA. Tell the user CI did not run for $short and that the push is unverified by CI; do not poll for it."
fi
pending=$(pending_of "$runs")
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
