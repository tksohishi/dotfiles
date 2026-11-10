#!/usr/bin/env bash
# PostToolUse (Bash) hook, wired with asyncRewake: after a push recorded by
# ci-gate-record.sh, wait in the background for every Actions run of that SHA.
# Green exits 0 silently. Red, or CI that never runs or finishes, exits 2 so its
# stderr wakes the session, even when idle, and the agent handles it. The session
# is never held: the turn ends while this runs.
set -eu
dir="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}"
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
[[ "$cmd" =~ (^|[;&|][[:space:]]*)git[[:space:]]+push ]] || exit 0
cwd=$(echo "$input" | jq -r '.cwd // ""')
sid=$(echo "$input" | jq -r '.session_id')
sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || exit 0
short=${sha:0:7}
marker="$dir/$sid.json"
ours() { [ -f "$marker" ] && [ "$(jq -r '.sha' "$marker")" = "$sha" ]; }

# ci-gate-record.sh runs in parallel and writes the marker only for pushes some workflow runs for.
for _ in $(seq "${CI_GATE_MARKER_WAIT:-10}"); do ours && break; sleep 1; done
ours || exit 0

fetch_runs() { (cd "$cwd" && gh run list --commit "$sha" --json databaseId,workflowName,status,conclusion 2>/dev/null) || echo '[]'; }
wake() { rm -f "$marker"; echo "CI gate: $1" >&2; exit 2; }
unverified() {
  local status
  status=$(curl -s -m 5 https://www.githubstatus.com/api/v2/components.json | jq -r '.components[] | select(.name=="Actions") | .status' 2>/dev/null || true)
  wake "$1 (githubstatus Actions: ${status:-unknown}). Tell the user CI is unverified for $short; do not poll for it."
}

pushed_at=$(jq -r '.pushedAt' "$marker")
deadline=$(( pushed_at + ${CI_GATE_WAIT_MAX:-1500} ))
norun_deadline=$(( pushed_at + ${CI_GATE_NORUN_MAX:-120} ))
queued_deadline=$(( pushed_at + ${CI_GATE_QUEUED_MAX:-300} ))
while :; do
  ours || exit 0
  runs=$(fetch_runs)
  now=$(date +%s)
  if [ "$(echo "$runs" | jq 'length')" = 0 ]; then
    [ "$now" -ge "$norun_deadline" ] && unverified "GitHub created no Actions run for pushed commit $short in $(( now - pushed_at )) s"
  else
    pending=$(echo "$runs" | jq -r '[.[] | select(.status != "completed")] | map("\(.workflowName) (\(.databaseId))") | join(", ")')
    [ -z "$pending" ] && break
    [ "$now" -ge "$queued_deadline" ] && [ "$(echo "$runs" | jq '[.[] | select(.status == "in_progress")] | length')" = 0 ] \
      && unverified "Actions runs for $short never started ($pending)"
    [ "$now" -ge "$deadline" ] && unverified "Actions runs for $short still running after $(( now - pushed_at )) s ($pending)"
  fi
  sleep "${CI_GATE_WAIT_INTERVAL:-15}"
done

red=$(echo "$runs" | jq -r '[.[] | select(.conclusion != "success")] | map("\(.workflowName) (\(.databaseId)): \(.conclusion)") | join(", ")')
[ -n "$red" ] && wake "runs for $short did NOT all pass: $red. Tell the user CI is RED (do not say green), show the failing step via gh run view <id> --log-failed, and either fix it or state plainly that it is unfixed."
rm -f "$marker"
exit 0
