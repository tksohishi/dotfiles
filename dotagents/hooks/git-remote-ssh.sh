#!/bin/bash
# Pre-hook: a GitHub remote is registered over SSH, never HTTPS.
#
# Blocks:
#   `git remote add <name> https://github.com/...` and
#   `git remote set-url <name> https://github.com/...` (with or without
#   `git -C <dir>`). An HTTPS remote pushes with the gh OAuth token, whose
#   scopes are narrower than the SSH key: a push that touches
#   .github/workflows is rejected without the `workflow` scope, while every
#   other repo on this account pushes over SSH.
#
# Not blocked:
#   - `git clone https://github.com/...`: reading a third-party repo over
#     HTTPS needs no key and is the normal form for a scratch clone.
#   - HTTPS remotes on other hosts.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

HTTPS_REMOTE_RE='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+remote[[:space:]]+(add|set-url)[[:space:]][^;&|]*https://github\.com/'

if ! [[ "$CMD" =~ $HTTPS_REMOTE_RE ]]; then
  exit 0
fi

jq -nc --arg reason "Register GitHub remotes over SSH: git@github.com:<owner>/<repo>.git, not https://github.com/<owner>/<repo>.git. An HTTPS remote pushes with the gh OAuth token (no workflow scope); SSH is what every other repo here uses." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
