#!/bin/bash
# Pre-hook: refuse a file-rewriting script (Bash command or Write content that
# writes a file back) whose .replace()/.replaceAll() takes a non-function
# replacement. A string replacement treats $$, $&, $' and $` as patterns, so
# source holding `$${x}` or `$'` is silently mangled on the way back to disk.
# A function replacement (`() => b`) or split(a).join(b) inserts b verbatim.
# Fail open: missing jq/rg or unparsable input exits silently.

INPUT=$(cat)
TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .tool_input.content // empty' 2>/dev/null) || exit 0
[ -n "$TEXT" ] || exit 0
command -v rg >/dev/null 2>&1 || exit 0

printf '%s' "$TEXT" | rg -q 'Bun\.write|writeFile(Sync)?\(' || exit 0
printf '%s' "$TEXT" | rg -qP '\.replace(All)?\((?:[^(),]|\([^()]*\))+,(?!\s*(?:async\s*)?(?:\([^()]*\)|\w+)\s*=>|function\b)' || exit 0

echo "replace-dollar: a script that writes a file uses .replace() with a string replacement, which rewrites \$\$, \$&, \$' and \$\` in it. Pass a function (s.replace(a, () => b)) or use s.split(a).join(b); for an exact edit, use the Edit tool." >&2
exit 2
