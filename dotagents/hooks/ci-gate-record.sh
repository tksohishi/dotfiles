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
[ -d "$cwd/.github/workflows" ] || exit 0
sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || exit 0
sid=$(echo "$input" | jq -r '.session_id')
dir="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}"; mkdir -p "$dir"
jq -nc --arg cwd "$cwd" --arg sha "$sha" '{cwd:$cwd, sha:$sha, blocks:0}' > "$dir/$sid.json"
