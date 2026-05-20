#!/bin/bash
# Pre-hook: reject git commit when the subject line exceeds 80 characters.
# Enforces the subject + blank line + bullet-body format from AGENTS.md.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

if [[ ! "$CMD" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

# Extract the first -m "..." or -m '...' argument. Edge cases (escaped
# quotes inside the message, --message=, -F <file>) are not handled.
MSG=""
if [[ "$CMD" =~ -m[[:space:]]+\"([^\"]*)\" ]]; then
  MSG="${BASH_REMATCH[1]}"
elif [[ "$CMD" =~ -m[[:space:]]+\'([^\']*)\' ]]; then
  MSG="${BASH_REMATCH[1]}"
fi

if [ -z "$MSG" ]; then
  exit 0
fi

SUBJECT="${MSG%%$'\n'*}"
LEN=${#SUBJECT}

if [ "$LEN" -le 80 ]; then
  exit 0
fi

HAS_BODY="false"
if [[ "$MSG" == *$'\n'* ]]; then
  HAS_BODY="true"
fi

if [ "$HAS_BODY" = "true" ]; then
  DETAIL="Shorten the subject to a single focused concept and move the rest into the bullet body."
else
  DETAIL="Add a blank line after the subject, then a bullet body explaining what + why."
fi

REASON="Commit subject is ${LEN} chars (limit 80). ${DETAIL} See AGENTS.md Commits section for the subject + body + bullets format."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'

exit 0
