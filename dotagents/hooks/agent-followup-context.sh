#!/bin/bash
# PreToolUse hook on Agent|SendMessage (Claude only): a named subagent gets
# the conversation at spawn (subagent-context.sh), but Claude Code drops
# SubagentStart context when a SendMessage resumes it. So record where the
# transcript stood when the agent was spawned or last messaged, and append
# the conversation since then, verbatim with speaker labels, to each
# SendMessage to that agent. Recipients this session did not spawn by name
# (other sessions, "main") are left alone.

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")
SESSION=$(jq -r '.session_id // ""' <<< "$INPUT")
TRANSCRIPT=$(jq -r '.transcript_path // ""' <<< "$INPUT")
CWD=$(jq -r '.cwd // ""' <<< "$INPUT")

[ -n "$SESSION" ] && [ -f "$TRANSCRIPT" ] && [ -d "$CWD" ] || exit 0

STATE_DIR="$CWD/tmp/agent-context/sent/$SESSION"
state_file() { printf '%s/%s' "$STATE_DIR" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')"; }
lines() { wc -l < "$TRANSCRIPT" | tr -d ' '; }

case "$TOOL" in
  Agent)
    NAME=$(jq -r '.tool_input.name // ""' <<< "$INPUT")
    [ -n "$NAME" ] || exit 0
    mkdir -p "$STATE_DIR"
    lines > "$(state_file "$NAME")"
    exit 0
    ;;
  SendMessage) ;;
  *) exit 0 ;;
esac

jq -e '.tool_input.message | type == "string"' <<< "$INPUT" >/dev/null || exit 0
TO=$(jq -r '.tool_input.to // ""' <<< "$INPUT")
STATE=$(state_file "$TO")
[ -f "$STATE" ] || exit 0

ROOT=$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)
AFTER=$(cat "$STATE")
NOW=$(lines)
EXCERPT=$("$ROOT/bin/transcript-excerpt" --transcript "$TRANSCRIPT" --after-line "$AFTER" --max-chars 20000 2>/dev/null) || exit 0
printf '%s\n' "$NOW" > "$STATE"
[ -n "$(printf '%s' "$EXCERPT" | tr -d '[:space:]')" ] || exit 0

NOTE="Conversation in the delegating session since you last heard from it, verbatim. \"User:\" is the user's own words; \"Claude:\" is the delegating session's take. Where the message above conflicts with what the user said, follow the user and say so."

jq -c --arg ctx "$NOTE

$EXCERPT" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: (.tool_input + {message: (.tool_input.message + "\n\n---\n" + $ctx)})
  }
}' <<< "$INPUT"
exit 0
