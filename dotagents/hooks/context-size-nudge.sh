#!/bin/bash
# UserPromptSubmit: once the main context passes 300K tokens, and again at each
# further 100K, show the user its size and have the agent offer a /handoff into
# a fresh session at the next task boundary. Every request re-reads the whole
# context, so a long session pays its full size on every turn. Size is the last
# assistant message's input + cache read + cache write tokens. The band resets
# when the context shrinks (compaction), so re-growing past 300K fires again.

INPUT=$(cat)
T=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SID=$(echo "$INPUT" | jq -r '.session_id // empty')
[ -f "$T" ] && [ -n "$SID" ] || exit 0

ctx=$(tail -n 200 "$T" | jq -r 'select(.type == "assistant" and .message.usage) | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null | tail -n 1)
[ -n "$ctx" ] || exit 0

band=$((ctx / 100000))
state="$TMPDIR/claude-context-nudge-$SID"
prev=$(cat "$state" 2>/dev/null || echo 0)
[ "$band" = "$prev" ] || echo "$band" > "$state"
[ "$band" -ge 3 ] && [ "$band" -gt "$prev" ] || exit 0

k=$((ctx / 1000))
MSG="Context is ${k}K tokens; every turn re-reads all of it."
CTX="This session's context is ${k}K tokens, and every request re-reads all of it. Finish the current request first. At the next natural task boundary, tell the user the size once and offer /handoff into a fresh session. If the user says they are stepping away and coming back within a few hours, suggest /keepalive instead so the cache does not expire; if they are done with this thread for the day, the handoff is the better choice."

jq -nc --arg msg "$MSG" --arg ctx "$CTX" '{
  systemMessage: $msg,
  hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: $ctx }
}'
exit 0
