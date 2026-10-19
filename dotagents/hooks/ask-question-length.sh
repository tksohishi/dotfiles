#!/bin/bash
# Pre-hook: deny an AskUserQuestion whose question or option text is long, so
# background goes in the response body and the dialog carries only the choice.
# Previews are exempt: mockups and code comparisons are meant to be long.

MAX=150

LONG=$(jq -r --argjson max "$MAX" '
  [.tool_input.questions[]? |
    (select((.question // "") | length > $max) | "question \"\(.header // "")\""),
    (.options[]? | select((.description // "") | length > $max) | "option \"\(.label)\"")
  ] | join(", ")')

[ -z "$LONG" ] && exit 0

jq -nc --arg reason "AskUserQuestion text over $MAX characters ($LONG). Write the background, trade-offs and details in your response text first, then call AskUserQuestion again with a one-sentence question and short option descriptions that only name each choice and its key consequence." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
