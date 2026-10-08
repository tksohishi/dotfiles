#!/bin/bash
# SessionStart: load tmp/handoff.md (written by the handoff skill) into a
# session started fresh after /clear or launch, then trash it so the one-shot
# handoff can't be loaded twice. Resume, compact and fork keep their own
# history, so they leave the file alone.
f="tmp/handoff.md"
[ -f "$f" ] || exit 0
case "$(jq -r '.source // empty' 2>/dev/null)" in
  clear | startup) ;;
  *) exit 0 ;;
esac
mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f")
# additionalContext is model-only; systemMessage shows the user the title plus
# the first paragraph of Goal and Next step.
summary=$(awk '
  NR == 1 && /^# / { sub(/^# /, ""); print; next }
  /^## (Goal|Next step)$/ { sec = substr($0, 4); grab = 1; started = 0; next }
  /^## / { grab = 0 }
  grab && /^$/ { if (started) grab = 0; next }
  grab { printf "%s%s\n", (started ? "  " : sec ": "), $0; started = 1 }
' "$f")
jq -n --rawfile doc "$f" --arg mtime "$mtime" --arg summary "$summary" '{systemMessage: ("Handoff loaded (tmp/handoff.md, \($mtime), now in the Trash)\n" + $summary), hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Handoff from the previous session (tmp/handoff.md, written \($mtime); the file is now in the Trash). Before answering the first prompt: re-ground its claims against git log/status and live state (fresh evidence wins over the file); move still-true facts that code, git or memory cannot supply into topic memories; delete any session-state memory it supersedes (open-threads or state-on-date files) with its MEMORY.md line; then continue with its next step.\n\n" + $doc)}}'
trash "$f"
