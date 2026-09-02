#!/usr/bin/env bash
# PostToolUse (Bash) hook: after a `git push`, record the pushed SHA for this
# session so ci-gate.sh (Stop hook) can refuse to end the turn until every
# GitHub Actions run for that commit is green. Deterministic replacement for
# "remember to watch CI" reminders, which failed Aug 24 2026 (a chained watch
# command masked a red run and the turn ended reporting green).
set -eu
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
[[ "$cmd" =~ (^|[;&|][[:space:]]*)git[[:space:]]+push ]] || exit 0
cwd=$(echo "$input" | jq -r '.cwd // ""')

# Only gate repos with a workflow that runs on push or pull_request; a repo
# whose only workflow is issue- or schedule-triggered never produces runs for
# the pushed SHA, and the Stop hook would block on an empty run list until its
# retry budget ran out. Same parser as ci-gate.sh; keep them in sync.
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
has_push_workflow "$cwd" || exit 0
sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || exit 0
sid=$(echo "$input" | jq -r '.session_id')
dir="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}"; mkdir -p "$dir"
jq -nc --arg cwd "$cwd" --arg sha "$sha" '{cwd:$cwd, sha:$sha, blocks:0}' > "$dir/$sid.json"
