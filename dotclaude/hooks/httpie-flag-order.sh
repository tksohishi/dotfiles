#!/bin/bash
# Pre-hook: enforce httpie canonical invocation order.
#
# Blocks:
#   `http -<flag> ...` or `https -<flag> ...` when a URL or HTTP method
#   appears later in the command. Canonical form is
#     http [METHOD] <URL> [flags...]
#   so the allowlist can be small and unambiguous.
#
# Not blocked:
#   - `http --help` / `http --version` (no URL/method follows)
#   - `curl -s ... | http ...` and similar pipelines where `http` is not
#     the first token on the segment
#
# Limitations:
# - Only inspects the first command segment. Pipelines/chains after `|`,
#   `&&`, `;` are not scanned.
# - Method detection is case-sensitive on the standard verbs.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

HTTP_FLAG_FIRST_RE='^[[:space:]]*https?[[:space:]]+-'
HELP_VERSION_ONLY_RE='^[[:space:]]*https?[[:space:]]+--(help|version)[[:space:]]*$'

REASON=""

if [[ "$CMD" =~ $HTTP_FLAG_FIRST_RE ]] && ! [[ "$CMD" =~ $HELP_VERSION_ONLY_RE ]]; then
  REASON="Don't put flags between 'http'/'https' and the URL. Canonical form: 'http [METHOD] <URL> [flags...]'. Move flags to after the URL."
fi

if [ -z "$REASON" ]; then
  exit 0
fi

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
