#!/bin/bash
# Pre-hook: block U+2014 (emdash) in prose-style content written via Write,
# Edit, or NotebookEdit.
#
# Per ~/.claude/CLAUDE.md Writing Style: "Avoid using emdashes in writing".
# Emdash has a detectable signature (single Unicode codepoint), so the rule
# belongs at Enforcement Hierarchy level 1 (deterministic), not 3 (soft
# guidance). Promoted because it kept drifting.
#
# Scope:
#   1. Only fires on prose files: .md, .markdown, .txt, .rst. Source code,
#      config, and structured data are exempt; U+2014 there is usually
#      intentional (comments, error messages) and the rule was about
#      written prose, not symbols in code.
#   2. Files targeted at AI agents (AGENTS.md, SKILL.md, etc.) are exempt
#      by basename. The rule is for prose written for human readers;
#      agent-targeted files often use emdash stylistically in lead-in
#      lines and the user accepts that. The basename list lives in
#      no-emdash-skip-basenames.txt next to this script; add more there.
#   3. U+2014 only. Does NOT enforce "hyphens or dashes as conjunctions":
#      too many false positives (compound nouns, ranges, ASCII hyphens used
#      correctly). Leave that as soft guidance.
#
# Bypass: replace U+2014 with comma, colon, period, or parentheses.
#
# Self-edit note: this script's source must NOT contain a literal U+2014
# anywhere, since editing this file would otherwise trip the active hook.
# The grep pattern below uses EMDASH=$(printf '\xe2\x80\x94') for that
# reason; do not replace it with a literal character.

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')

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

# Only fire on prose-shaped files.
case "$FILE_PATH" in
  *.md|*.markdown|*.txt|*.rst) ;;
  *) exit 0 ;;
esac

# Skip files where U+2014 is accepted stylistically.
# Basename list lives in no-emdash-skip-basenames.txt next to this script.
SCRIPT_DIR="$(dirname "$0")"
SKIP_FILE="$SCRIPT_DIR/no-emdash-skip-basenames.txt"
BASENAME=$(basename "$FILE_PATH")
if [ -f "$SKIP_FILE" ]; then
  while IFS= read -r skip; do
    skip=$(echo "$skip" | xargs)
    [ -z "$skip" ] && continue
    [[ "$skip" = \#* ]] && continue
    if [ "$BASENAME" = "$skip" ]; then
      exit 0
    fi
  done < "$SKIP_FILE"
fi

EMDASH=$(printf '\xe2\x80\x94')
if ! printf '%s' "$CONTENT" | grep -q "$EMDASH"; then
  exit 0
fi

# Excerpt around the first emdash: up to 40 chars on each side, single line.
EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE ".{0,40}${EMDASH}.{0,40}" | head -1)

REASON="Emdash detected in $FIELD. Replace with comma, colon, period, or parentheses per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
