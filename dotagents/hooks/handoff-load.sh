#!/bin/bash
# SessionStart: load tmp/handoff.md (written by the handoff skill) into a
# session started fresh after /clear or launch, then trash it so the one-shot
# handoff can't be loaded twice. Resume, compact and fork keep their own
# history, so they leave the file alone.
f="tmp/handoff.md"
# A session that wrote the file by hand may have dated the name
# (tmp/handoff-2026-10-09.md, 10/9): fall back to the newest tmp/handoff*.md.
[ -f "$f" ] || f=$(ls -t tmp/handoff*.md 2>/dev/null | head -1)
[ -n "$f" ] && [ -f "$f" ] || exit 0
case "$(jq -r '.source // empty' 2>/dev/null)" in
  clear | startup) ;;
  *) exit 0 ;;
esac
mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f")
# additionalContext is model-only; systemMessage shows the user the title plus
# one line each for Goal and Next step, cut to 80 chars: Claude Code prefixes
# every systemMessage line with "SessionStart:clear says:", so it stays short.
# The cut is in jq, not awk: macOS awk counts bytes and splits a Japanese char.
summary=$(awk '
  NR == 1 && /^# / { sub(/^# /, ""); print; next }
  /^## (Goal|Next step)$/ { sec = substr($0, 4); grab = 1; next }
  /^## / { grab = 0 }
  grab && /^$/ { next }
  grab {
    sub(/^[0-9]+\. /, "")
    printf "%s: %s\n", sec, $0; grab = 0
  }
' "$f")
jq -n --rawfile doc "$f" --arg f "$f" --arg mtime "$mtime" --arg summary "$summary" '($summary | split("\n") | map(if length > 80 then .[0:80] + "…" else . end) | join("\n")) as $summary | {systemMessage: ("Handoff loaded (\($f), \($mtime), now in the Trash)\n" + $summary), hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Handoff from the previous session (\($f), written \($mtime); the file is now in the Trash). Before answering the first prompt: re-ground its claims against git log/status and live state (fresh evidence wins over the file); move still-true facts that code, git or memory cannot supply into topic memories; delete any session-state memory it supersedes (open-threads or state-on-date files) with its MEMORY.md line; then continue with its next step.\n\n" + $doc)}}'
trash "$f"
