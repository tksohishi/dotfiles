#!/bin/bash
# Pre-hook: block name/date attribution clauses such as "(Takeshi, Aug 2026)"
# written into agent instruction files (AGENTS.md, CLAUDE.md, SKILL.md,
# .cursorrules). Rules in those files stand as they are now; authorship and
# dates are derivable from git history and read as noise to the next agent.
#
# Signature is a regex (parenthetical: capitalized name, comma, month, year),
# so this belongs at Enforcement Hierarchy level 1 (deterministic hook).
#
# Claude fires via Write|Edit|NotebookEdit; Codex fires via apply_patch
# (all tool_input strings are scanned, since the patch text carries both
# the target filenames and the added content).

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

case "$TOOL_NAME" in
  Write)
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // ""')
    FIELD="content"
    ;;
  Edit|NotebookEdit)
    FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.new_string // ""')
    FIELD="new_string"
    ;;
  apply_patch)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '[.tool_input | .. | strings] | join("\n")')
    FILE_PATH="$CONTENT"
    FIELD="patch"
    ;;
  *)
    exit 0
    ;;
esac

# Only fire when an instruction file is the target.
case "$FILE_PATH" in
  *AGENTS.md*|*CLAUDE.md*|*SKILL.md*|*.cursorrules*) ;;
  *) exit 0 ;;
esac

MONTHS='(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
PATTERN="\([A-Z][A-Za-z .'-]*, *${MONTHS}[a-z]*\.? *20[0-9]{2}\)"

MATCH=$(printf '%s' "$CONTENT" | grep -m1 -oE "$PATTERN")
if [ -z "$MATCH" ]; then
  exit 0
fi

REASON="Name/date attribution ${MATCH} detected in ${FIELD} targeting an instruction file. State the rule as it stands now, with rationale; drop names and dates (authorship and history live in git). Per AGENTS.md hygiene: no personal info, no version-history clauses."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
