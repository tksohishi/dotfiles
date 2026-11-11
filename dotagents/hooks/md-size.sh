#!/bin/bash
# Post-hook: after Write/Edit of a Markdown file inside a git repo, warn the
# agent when a prose line or the whole file has grown past what search and
# Read handle well. Warns only; never blocks.
#
#   - A line over MAX_LINE characters outside code fences and tables: one
#     rg hit returns the whole line, so a 5,000-character paragraph costs
#     that much per match.
#   - A file over MAX_BYTES: a full Read costs tens of thousands of tokens.
#     Bytes, not lines, because long-line files pass any line-count limit.
#
# Skips files that rg would not list from the repo top (.gitignore, .ignore,
# .rgignore): mirrors and archives hidden from search, and gitignored scratch
# such as tmp/. Files outside a git repo are skipped.

MAX_LINE=1000
MAX_BYTES=40000

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE" in
  *.md|*.markdown) ;;
  *) exit 0 ;;
esac
[ -f "$FILE" ] || exit 0

DIR=$(dirname "$FILE")
TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
REAL=$(cd "$DIR" && pwd -P)/$(basename "$FILE")
TOPREAL=$(cd "$TOP" && pwd -P)
REL=${REAL#"$TOPREAL"/}
[ "$REL" = "$REAL" ] && exit 0

LISTED=$(cd "$TOPREAL" && rg --files --hidden -g "/$REL" 2>/dev/null)
[ "$LISTED" = "$REL" ] || exit 0

LONG=$(awk -v max="$MAX_LINE" '
  /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
  fence { next }
  /^[[:space:]]*\|/ { next }
  { n = length($0); if (n > max) { c++; if (n > worst) { worst = n; at = NR } } }
  END { if (c) printf "%d %d %d", c, worst, at }
' "$FILE")
BYTES=$(wc -c < "$FILE" | tr -d ' ')

MSG=""
if [ -n "$LONG" ]; then
  read -r count worst at <<< "$LONG"
  MSG="$REL has $count prose line(s) over $MAX_LINE characters (longest: $worst at line $at). Every search hit returns the whole line. Split long paragraphs into shorter ones, or put one sentence per line."
fi
if [ "$BYTES" -gt "$MAX_BYTES" ]; then
  [ -n "$MSG" ] && MSG="$MSG "
  MSG="${MSG}$REL is $BYTES bytes (over $MAX_BYTES). A full Read costs tens of thousands of tokens. Consider splitting it by topic; move reference material nobody edits out of the searched tree."
fi
[ -z "$MSG" ] && exit 0

jq -nc --arg ctx "$MSG Warning only; finish the current task first and mention it to the user rather than restructuring unasked." '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
