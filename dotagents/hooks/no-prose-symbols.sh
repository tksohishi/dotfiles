#!/bin/bash
# Pre-hook: block stylistic Unicode symbols in prose-style content written
# via Write, Edit, or NotebookEdit. Currently checks:
#   - U+2014 emdash (avoid per Writing Style)
#   - U+00A7 § section sign (reads as an AI artifact in human-facing copy)
#
# Per ~/.claude/CLAUDE.md Writing Style. Both have a detectable signature
# (single Unicode codepoint), so the rule belongs at Enforcement Hierarchy
# level 1 (deterministic), not 3 (soft guidance).
#
# Scope:
#   1. Only fires on prose files: .md, .markdown, .txt, .rst. Source code,
#      config, and structured data are exempt; these symbols there are
#      usually intentional (comments, error messages, legal citations) and
#      the rule is about written prose, not symbols in code.
#   2. Files targeted at AI agents (AGENTS.md, SKILL.md, etc.) are exempt
#      by basename. The rule is for prose written for human readers;
#      agent-targeted files often use these symbols stylistically and the
#      user accepts that. The skip list lives in prose-skip-basenames.txt
#      next to this script. Two line formats are supported:
#        - No `/` → exact basename match (e.g. AGENTS.md, TODO.md)
#        - Contains `/` → path substring match (e.g. /memory/, /.claude/,
#          /dotclaude/). Anchor with leading and trailing slashes to bind
#          to directory boundaries.
#   3. Single-codepoint symbols only. Does NOT enforce broader typographic
#      preferences ("hyphens as conjunctions", etc.) — too many false
#      positives. Leave those as soft guidance.
#
# Bypass:
#   - Emdash → comma, colon, period, or parentheses.
#   - § → the word "Section", "see", or omit the marker.
#
# Self-edit note: this script's source must NOT contain a literal emdash
# or § anywhere — editing this file would otherwise trip the active hook
# (well, only on .md/.txt etc., but keep symbols out for symmetry and to
# avoid surprises if scope ever expands). Construct symbols at runtime
# via printf '\xHH...' below.

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

# Skip agent-targeted basenames (shared list).
SCRIPT_DIR="$(dirname "$0")"
SKIP_FILE="$SCRIPT_DIR/prose-skip-basenames.txt"
BASENAME=$(basename "$FILE_PATH")
if [ -f "$SKIP_FILE" ]; then
  while IFS= read -r skip; do
    skip=$(echo "$skip" | xargs)
    [ -z "$skip" ] && continue
    [[ "$skip" = \#* ]] && continue
    if [[ "$skip" = */* ]]; then
      case "$FILE_PATH" in
        *"$skip"*) exit 0 ;;
      esac
    elif [ "$BASENAME" = "$skip" ]; then
      exit 0
    fi
  done < "$SKIP_FILE"
fi

EMDASH=$(printf '\xe2\x80\x94')
SECTION=$(printf '\xc2\xa7')

REASON=""

if printf '%s' "$CONTENT" | grep -q "$EMDASH"; then
  EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE ".{0,40}${EMDASH}.{0,40}" | head -1)
  REASON="Emdash (U+2014) detected in $FIELD. Replace with comma, colon, period, or parentheses per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"
elif printf '%s' "$CONTENT" | grep -q "$SECTION"; then
  EXCERPT=$(printf '%s' "$CONTENT" | grep -m1 -oE ".{0,40}${SECTION}.{0,40}" | head -1)
  REASON="Section sign (U+00A7) detected in $FIELD. Reads as an AI artifact in human-facing copy. Replace with the word 'Section', 'see', or omit the marker per ~/.claude/CLAUDE.md Writing Style. Excerpt: …${EXCERPT}…"
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
