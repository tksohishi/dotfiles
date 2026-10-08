#!/bin/bash
# SessionStart: flag a lingering tmp/handoff.md so it can't feed stale facts.
# Handoffs are one-shot (see the handoff skill); a surviving file means it was
# never consumed and its contents must not be treated as current state.
f="tmp/handoff.md"
[ -f "$f" ] || exit 0
mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || echo "unknown date")
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"tmp/handoff.md exists (written %s). Handoffs are one-shot: run /handoff resume to ingest it (re-ground every claim against git/live state first) and then delete it. If its work is already done, salvage still-true non-derivable facts to memory and delete it. Do NOT cite its contents as current state."}}\n' "$mtime"
