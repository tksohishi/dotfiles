#!/bin/bash
# Pre-hook: block stylistic Unicode symbols in publish-bound prose written
# via Write, Edit, or NotebookEdit. Currently checks:
#   - U+2014 emdash (avoid per Writing Style)
#   - U+00A7 § section sign (reads as an AI artifact in human-facing copy)
#
# Per ~/.claude/CLAUDE.md Writing Style. Both have a detectable signature
# (single Unicode codepoint), so the rule belongs at Enforcement Hierarchy
# level 1 (deterministic), not 3 (soft guidance).
#
# Scope (allowlist model, 2026-06-10):
#   Fires ONLY on files matching a publish signature listed in
#   prose-publish-paths.txt next to this script. Everything else is skipped;
#   the CLAUDE.md Writing Style rule still applies as soft guidance there.
#   Rationale: the set of non-publish files is open-ended (the old skip-list
#   grew without bound), while publish locations are enumerable. Register a
#   new publish location once instead of exempting every personal file.
#
#   Two line formats in prose-publish-paths.txt:
#     - Contains `/` → path substring match (e.g. /drafts/, /posts/).
#       Anchor with leading and trailing slashes to bind to directory
#       boundaries.
#     - No `/` → basename glob match (e.g. DRAFT*, *.draft.md)
#
#   Extension gate: .md, .markdown, .txt, .rst, .html (html for email
#   bodies composed by drafting skills).
#
# Bypass:
#   - Emdash → comma, colon, period, or parentheses.
#   - § → the word "Section", "see", or omit the marker.
#
# Self-edit note: this script's source must NOT contain a literal emdash
# or § anywhere. Construct symbols at runtime via printf '\xHH...' below.

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
  *.md|*.markdown|*.txt|*.rst|*.html) ;;
  *) exit 0 ;;
esac

# Fire only on publish-bound paths (shared allowlist).
SCRIPT_DIR="$(dirname "$0")"
PUBLISH_FILE="$SCRIPT_DIR/prose-publish-paths.txt"
BASENAME=$(basename "$FILE_PATH")
MATCHED=""
if [ -f "$PUBLISH_FILE" ]; then
  while IFS= read -r pattern; do
    pattern=$(echo "$pattern" | xargs)
    [ -z "$pattern" ] && continue
    [[ "$pattern" = \#* ]] && continue
    if [[ "$pattern" = */* ]]; then
      case "$FILE_PATH" in
        *"$pattern"*) MATCHED=1; break ;;
      esac
    else
      case "$BASENAME" in
        $pattern) MATCHED=1; break ;;
      esac
    fi
  done < "$PUBLISH_FILE"
fi
[ -z "$MATCHED" ] && exit 0

EMDASH=$(printf '\xe2\x80\x94')
SECTION=$(printf '\xc2\xa7')

REASON=""

if printf '%s' "$CONTENT" | grep -q "$EMDASH"; then
  EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE ".{0,40}${EMDASH}.{0,40}" | head -1)
  REASON="Emdash (U+2014) detected in $FIELD of a publish-bound file. Replace with comma, colon, period, or parentheses per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"
elif printf '%s' "$CONTENT" | grep -q "$SECTION"; then
  EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE ".{0,40}${SECTION}.{0,40}" | head -1)
  REASON="Section sign (U+00A7) detected in $FIELD of a publish-bound file. Reads as an AI artifact in human-facing copy. Replace with the word 'Section', 'see', or omit the marker per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"
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
