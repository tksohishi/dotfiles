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
# The desktop app does not render systemMessage, so outside the CLI the agent relays the notice.
unverified() {
  [ "${CLAUDE_CODE_ENTRYPOINT:-}" = cli ] || block "$1 The gate will not wait again for this SHA. Tell the user CI is unverified for $short; do not poll for it."
  jq -n --arg m "$1" '{systemMessage:$m}'; exit 0
}
fetch_runs() { (cd "$cwd" && gh run list --commit "$sha" --json databaseId,workflowName,status,conclusion 2>/dev/null) || echo '[]'; }
pending_of() { echo "$1" | jq -r '[.[] | select(.status != "completed")] | map("\(.workflowName) (\(.databaseId))") | join(", ")'; }

# Whether a workflow in $1 runs for a push of the SHA to any branch named in the
# remaining arguments; with no branch names, any push or pull_request trigger
# counts. Reads push.branches / branches-ignore / tags (a tags-only push filter
# never fires for a branch); pull_request counts only when the branch has an
# open PR. Same function in ci-gate.sh and ci-gate-record.sh; keep them in sync.
workflow_targets() {
  local dir=$1 f spec br kind pat neg hit; shift
  for f in "$dir"/.github/workflows/*.yml "$dir"/.github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    spec=$(awk '
      function strip(s) { gsub(/^[[:space:]"\047]+|[[:space:]"\047]+$/, "", s); return s }
      function emit(k, s,   n, a, i) { gsub(/[][]/, "", s); n = split(s, a, ","); for (i = 1; i <= n; i++) if (strip(a[i]) != "") print k, strip(a[i]) }
      function endpush() { if (ev == "push" && !filt) print "any"; ev = "" }
      /^[[:space:]]*(#|$)/ { next }
      /^("on"|\047on\047|on)[[:space:]]*:/ {
        inon = 1; evind = 0; v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
        if (v ~ /(^|[^a-z_])push([^a-z_]|$)/) print "any"
        if (v ~ /(^|[^a-z_])pull_request([^a-z_]|$)/) print "pr"
        next
      }
      !inon { next }
      /^[^[:space:]]/ { endpush(); inon = 0; next }
      {
        match($0, /^[[:space:]]*/); ind = RLENGTH
        s = substr($0, ind + 1); sub(/[[:space:]]+#.*/, "", s)
        if (!evind) evind = ind
        if (ind <= evind) {
          endpush(); sub(/^-[[:space:]]*/, "", s); key = s; sub(/[[:space:]]*:.*/, "", key)
          if (key == "push") { ev = "push"; filt = 0; lk = "" }
          else if (key == "pull_request") print "pr"
          next
        }
        if (ev != "push") next
        if (s ~ /^-/) { if (lk != "") emit(lk, substr(s, 2)); next }
        key = s; sub(/[[:space:]]*:.*/, "", key); val = s; sub(/^[^:]*:[[:space:]]*/, "", val)
        lk = ""
        if (key == "branches") lk = "b"; else if (key == "branches-ignore") lk = "i"
        if (key ~ /^(branches|branches-ignore|tags|tags-ignore)$/) filt = 1
        if (lk != "" && val != "") emit(lk, val)
      }
      END { endpush() }
    ' "$f")
    [ -n "$spec" ] || continue
    [ $# -eq 0 ] && return 0
    grep -qx any <<< "$spec" && return 0
    for br in "$@"; do
      if grep -qx pr <<< "$spec"; then
        [ "$(cd "$dir" && gh pr list --head "$br" --state open --json number --jq length 2>/dev/null)" != 0 ] && return 0
      fi
      grep -qE '^[bi] ' <<< "$spec" || continue
      if grep -q '^b ' <<< "$spec"; then hit=0; else hit=1; fi
      while read -r kind pat; do
        neg=0; [[ $pat == '!'* ]] && { neg=1; pat=${pat#!}; }
        [[ $br == $pat ]] || continue
        if [ "$kind" = b ]; then hit=$((1 - neg)); else hit=$neg; fi
      done < <(grep -E '^[bi] ' <<< "$spec")
      [ "$hit" = 1 ] && return 0
    done
  done
  return 1
}

runs=$(fetch_runs)
# Second line of defense behind ci-gate-record.sh: a marker no workflow can resolve is dropped instead of blocking.
if [ "$(echo "$runs" | jq 'length')" = "0" ] && ! workflow_targets "$cwd" $(jq -r '.branches // [] | .[]' "$marker"); then rm -f "$marker"; exit 0; fi

# Poll until every run has completed (runs that have not appeared yet count as
# pending) or the wait bound is reached. The bound must stay under the hook's
# timeout in settings.json, or the harness kills the hook and nothing is checked.
deadline=$(( $(date +%s) + ${CI_GATE_WAIT_MAX:-480} ))
# No run CI_GATE_NORUN_MAX seconds after the push, no pending run started CI_GATE_QUEUED_MAX
# seconds after it, or githubstatus saying Actions is not operational ends the gate with one
# report: the agent cannot make GitHub create or start a run.
pushed_at=$(jq -r '.pushedAt // empty' "$marker"); pushed_at=${pushed_at:-$(stat -f %m "$marker")}
norun_deadline=$(( pushed_at + ${CI_GATE_NORUN_MAX:-120} ))
queued_deadline=$(( pushed_at + ${CI_GATE_QUEUED_MAX:-300} ))
actions_status=$(curl -s -m 5 https://www.githubstatus.com/api/v2/components.json | jq -r '.components[] | select(.name=="Actions") | .status' 2>/dev/null || true)
degraded() { [ -n "$actions_status" ] && [ "$actions_status" != operational ]; }
stalled() { [ "$(date +%s)" -ge "$queued_deadline" ] && [ "$(echo "$runs" | jq '[.[] | select(.status == "in_progress")] | length')" = "0" ]; }
while :; do
  [ "$(echo "$runs" | jq 'length')" != "0" ] && [ -z "$(pending_of "$runs")" ] && break
  [ "$(date +%s)" -ge "$deadline" ] && break
  degraded && break
  if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
    [ "$(date +%s)" -ge "$norun_deadline" ] && break
  else
    stalled && break
  fi
  sleep "${CI_GATE_WAIT_INTERVAL:-15}"
  runs=$(fetch_runs)
done

if [ "$(echo "$runs" | jq 'length')" = "0" ]; then
  rm -f "$marker"
  unverified "CI gate: GitHub created no Actions run for pushed commit $short in $(( $(date +%s) - pushed_at )) s (githubstatus Actions: ${actions_status:-unknown}). The push is unverified by CI."
fi
pending=$(pending_of "$runs")
if [ -n "$pending" ] && { degraded || stalled; }; then
  rm -f "$marker"
  unverified "CI gate: Actions runs for $short did not finish and GitHub Actions looks unhealthy (githubstatus Actions: ${actions_status:-unknown}; pending: $pending). The push is unverified by CI."
fi
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
