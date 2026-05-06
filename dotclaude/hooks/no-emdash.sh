#!/bin/bash
# Pre-hook: block emdashes (— / U+2014) in content written via Write,
# Edit, or NotebookEdit.
#
# Per ~/.claude/CLAUDE.md Writing Style: "Avoid using emdashes in writing".
# Emdashes have a detectable signature (single Unicode codepoint), so the
# rule belongs at Enforcement Hierarchy level 1 (deterministic), not 3
# (soft guidance). Promoted because it kept drifting.
#
# Triggers on Write (content field), Edit / NotebookEdit (new_string field).
# Other tools and other fields pass through.
#
# Scope: U+2014 only. Does NOT enforce "hyphens or dashes as conjunctions":
# too many false positives (compound nouns, ranges, ASCII hyphens used
# correctly). Leave that as soft guidance.
#
# Bypass: replace emdashes with comma, colon, period, or parentheses.
# No allowlist or escape hatch in v1; add one if a legit false positive
# surfaces (e.g., transcribing a quoted passage that authentically
# contains —).

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

case "$TOOL_NAME" in
  Write)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // ""')
    FIELD="content"
    ;;
  Edit|NotebookEdit)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.new_string // ""')
    FIELD="new_string"
    ;;
  *)
    exit 0
    ;;
esac

if ! printf '%s' "$CONTENT" | grep -q '—'; then
  exit 0
fi

# Excerpt around the first emdash: up to 40 chars on each side, single line.
EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE '.{0,40}—.{0,40}' | head -1)

REASON="Emdash detected in $FIELD. Replace with comma, colon, period, or parentheses per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
