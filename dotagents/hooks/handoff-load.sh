#!/bin/bash
# SessionStart: load the handoff file (written by the handoff skill) into a
# session started fresh after /clear or launch, then trash it so the one-shot
# handoff can't be loaded twice. Resume, compact and fork keep their own
# history, so they leave the file alone.
case "$(jq -r '.source // empty' 2>/dev/null)" in
  clear | startup) ;;
  *) exit 0 ;;
esac
# The skill names the file tmp/handoff-<CLAUDE_PID>.md, and /clear keeps the
# same claude process, so several sessions in one directory each get their own.
f="tmp/handoff-$CLAUDE_PID.md"
if [ -z "$CLAUDE_PID" ] || [ ! -f "$f" ]; then
  # A handoff whose writer is still running belongs to that session's /clear.
  f=""
  for c in $(ls -t tmp/handoff*.md 2>/dev/null); do
    pid=$(basename "$c" .md | sed -n 's/^handoff-\([0-9][0-9]*\)$/\1/p')
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && continue
    f="$c"
    break
  done
fi
[ -n "$f" ] && [ -f "$f" ] || exit 0
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
# The desktop app does not render systemMessage, so the model announces the load.
announce=" Open your first reply with one line naming this handoff by its file and title."
[ "${CLAUDE_CODE_ENTRYPOINT:-}" = cli ] && announce=""
jq -n --rawfile doc "$f" --arg f "$f" --arg mtime "$mtime" --arg summary "$summary" --arg announce "$announce" '($summary | split("\n") | map(if length > 80 then .[0:80] + "…" else . end) | join("\n")) as $summary | {systemMessage: ("Handoff loaded (\($f), \($mtime), now in the Trash)\n" + $summary), hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Handoff from the previous session (\($f), written \($mtime); the file is now in the Trash).\($announce) Before answering the first prompt: re-ground its claims against git log/status and live state (fresh evidence wins over the file); move still-true facts that code, git or memory cannot supply into topic memories; delete any session-state memory it supersedes (open-threads or state-on-date files) with its MEMORY.md line; then continue with its next step.\n\n" + $doc)}}'
trash "$f"
