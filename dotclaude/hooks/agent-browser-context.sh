#!/bin/bash
# Pre-hook: reminders when the agent is about to run agent-browser.
# Fires on Bash commands invoking agent-browser (skips --help / -h).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')
CWD=$(echo "$TOOL_INPUT" | jq -r '.cwd // empty')

if ! echo "$CMD" | grep -qE '^[[:space:]]*agent-browser[[:space:]]'; then
  exit 0
fi

if echo "$CMD" | grep -qE 'agent-browser[[:space:]]+(--help|-h)([[:space:]]|$)'; then
  exit 0
fi

REMINDERS="Check \`agent-browser --help\` for actual subcommands before running."

if [[ -n "$CWD" && ! -f "$CWD/agent-browser.json" ]]; then
  REMINDERS="$REMINDERS Project has no agent-browser.json; consider \`/agent-browser-init\` to isolate this project's browser state and enable parallel use with other projects."
fi

jq -nc --arg reason "$REMINDERS" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: $reason
  }
}'

exit 0
