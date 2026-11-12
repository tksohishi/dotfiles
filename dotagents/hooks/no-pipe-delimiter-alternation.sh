#!/bin/bash
# PreToolUse (Bash): refuse a perl or sed substitution delimited by `|` that carries `\|` in it. With `|` as the
# delimiter, `\|` is not a literal pipe but alternation, and an empty branch matches every line, so the substitution
# rewrites the whole file. The Edit tool, or a `#` delimiter with a literal `\|`, does what was meant.

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0
echo "$cmd" | grep -qE '(^|[^a-z])(perl|sed)([^a-z]|$)' || exit 0
echo "$cmd" | grep -qE '(^|[^a-z])s\|' || exit 0
echo "$cmd" | grep -qF '\|' || exit 0

jq -nc --arg reason 'no-pipe-delimiter-alternation: a `s|...|...|` substitution with `\|` in it. Under a `|` delimiter `\|` is alternation, not a pipe, and an empty branch rewrites every line. Use the Edit tool, or a `#` delimiter (s#a\|b#...#).' '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
