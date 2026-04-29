#!/bin/bash
# Pre-hook: block reflex creation of feedback-type memory files.
#
# Per dotagents/AGENTS.md Enforcement Hierarchy, behavior rules
# (corrections, "don't do X", "always Y") belong in AGENTS.md, not memory.
# Memory is for project-specific state, time-bound facts, user preferences,
# or watch items.
#
# Triggers on Write to a path under */memory/*.md when new content's
# frontmatter declares type: feedback. Other types (project, user, reference)
# pass through.
#
# Override: change frontmatter type, or update AGENTS.md directly.

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // ""')

if [[ ! "$FILE_PATH" =~ /memory/.*\.md$ ]]; then
  exit 0
fi

if ! echo "$CONTENT" | head -20 | grep -qE '^type:[[:space:]]*feedback[[:space:]]*$'; then
  exit 0
fi

REASON="Feedback-type memory blocked per Enforcement Hierarchy level 3. Surface to the user: this attempt may indicate ~/.dotfiles/dotagents/AGENTS.md needs a rule update to cover this case."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
