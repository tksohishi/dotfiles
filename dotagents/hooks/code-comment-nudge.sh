#!/bin/bash
# Post-hook: after Edit/Write on a code file, nudge when the change adds 2+
# full-line comments or any trailing end-of-line comment. Soft hint only;
# counts are new minus old, so editing around existing comments stays quiet.

TOOL_INPUT=$(cat)
FILE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

case "${FILE##*.}" in
  ts|tsx|js|jsx|mjs|cjs|swift|go|rs|c|h|cc|cpp|hpp|java|kt|kts|cs|scala|dart) MARK='//' ;;
  sh|bash|zsh|py|rb|toml|yaml|yml|pl|r) MARK='#' ;;
  sql|lua|hs) MARK='--' ;;
  *) exit 0 ;;
esac

PRAGMA='^[[:space:]]*(#!|# -\*-|# (noqa|type:|shellcheck|pyright:|pragma|fmt:)|// ?(@ts-|eslint|biome-ignore|prettier-ignore|swiftlint:|go:|nolint|/ ?<reference))'

NEW=$(echo "$TOOL_INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
OLD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.old_string // .tool_response.originalFile // empty')

full_count() {
  local block=''
  [ "$MARK" = '//' ] && block='|/\*|\*'
  printf '%s\n' "$1" | grep -vE "$PRAGMA" | grep -cE "^[[:space:]]*(${MARK}${block})"
}

trailing_count() {
  printf '%s\n' "$1" \
    | sed -E "s/\"([^\"\\\\]|\\\\.)*\"//g; s/'([^'\\\\]|\\\\.)*'//g; s/\`[^\`]*\`//g" \
    | grep -vE "^[[:space:]]*(${MARK}|/\*|\*)" \
    | grep -cE "[^[:space:]][[:space:]]+${MARK}([[:space:]]|$)"
}

FULL=$(( $(full_count "$NEW") - $(full_count "$OLD") ))
TRAIL=$(( $(trailing_count "$NEW") - $(trailing_count "$OLD") ))

if [ "$FULL" -lt 2 ] && [ "$TRAIL" -lt 1 ]; then
  exit 0
fi

REMINDER="This edit added ${FULL} comment line(s) and ${TRAIL} trailing comment(s) in $(basename "$FILE"). Code states current behavior; keep a comment only for a non-obvious constraint the code can't express. Move background, history and decision rationale to docs/ or the commit message, and drop trailing end-of-line comments."

jq -nc --arg ctx "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
