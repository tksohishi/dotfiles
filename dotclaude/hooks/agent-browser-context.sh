#!/bin/bash
# Pre-hook: remind agent to verify agent-browser subcommands via --help before running.
# Fires only when the Bash command invokes agent-browser (and isn't already --help).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

if echo "$CMD" | grep -qE '^[[:space:]]*agent-browser[[:space:]]'; then
  if ! echo "$CMD" | grep -qE 'agent-browser[[:space:]]+(--help|-h)([[:space:]]|$)'; then
    jq -nc '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "Check `agent-browser --help` for actual subcommands before running."
      }
    }'
    exit 0
  fi
fi

exit 0
