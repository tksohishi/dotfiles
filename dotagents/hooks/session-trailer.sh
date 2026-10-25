#!/bin/bash
# Pre-hook: reject a commit message or PR body that carries a Claude session link.

CMD=$(jq -r '.tool_input.command')

if [[ ! "$CMD" =~ (git[[:space:]]+commit|gh[[:space:]]+pr) ]]; then
  exit 0
fi

if [[ ! "$CMD" =~ (Claude-Session:|claude\.ai/code/session_) ]]; then
  exit 0
fi

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Remove the Claude-Session line and any claude.ai/code/session_ link: commit messages and PR bodies carry no session trailer (AGENTS.md Commits)."
  }
}'
