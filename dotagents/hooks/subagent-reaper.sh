#!/usr/bin/env bash
# SubagentStop hook: when a subagent reports, kill the background shells it
# started that are still running. The subagent stops while its shells live on
# until the Bash timeout (30m default, 2h max), and a model-issued kill can be
# blocked by the auto-mode classifier; the hook kills directly.
#
# Ownership is the harness's own record, never printed text: a Bash call that
# went to the background (run_in_background or a timed-out foreground call)
# carries toolUseResult.backgroundTaskId in this agent's transcript. Only ids
# that background_tasks also lists as a running shell qualify.
#
# Process: the shell whose stdout (fd 1) is tasks/<id>.output and that leads
# its own process group; the group is signalled so its children die too. Any
# reader of the file (tail -f) is skipped because it holds a different fd.
# The killed subagent resumes for one turn and stops again; by then nothing
# runs, so the second firing is a no-op.
set -u

TASKS_ROOT=${SUBAGENT_REAPER_TASKS_ROOT:-/tmp/claude-$(id -u)}

input=$(cat)
t=$(jq -r '.agent_transcript_path // empty' <<<"$input")
[ -f "$t" ] || exit 0
running=$(jq -r '.background_tasks[]? | select(.type == "shell" and .status == "running") | .id' <<<"$input")
[ -z "$running" ] && exit 0
owned=$(jq -r 'select(.type == "user") | .toolUseResult | objects | .backgroundTaskId // empty' "$t" 2>/dev/null | sort -u)

self=$(ps -o pgid= -p $$ | tr -d ' ')
for id in $owned; do
  grep -qx "$id" <<<"$running" || continue
  for f in "$TASKS_ROOT"/*/*/tasks/"$id".output; do
    [ -f "$f" ] || continue
    for pid in $(lsof -a -d 1 -t "$f" 2>/dev/null); do
      pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')
      [ "$pid" = "$pgid" ] && [ "$pgid" != "$self" ] || continue
      kill -TERM -- "-$pgid" 2>/dev/null && echo "subagent-reaper: sent TERM to $id (pgid $pgid)" >&2
    done
  done
done
exit 0
