#!/bin/bash
# Pre-hook: block zsh-only parameter expansions in Bash commands: flag forms such as
# ${(f)...} and ${=var}, and $(<file). Claude Code's command parser cannot read them, so
# the command falls to a manual approval ("Dangerous rm operation not ruled out")
# even when it only runs a script. A list of arguments that lives in a file is read by the
# script itself: pass the file path as the argument.
# Fail open: missing jq/rg or unparsable input exits silently.
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$CMD" ] || exit 0
command -v rg >/dev/null 2>&1 || exit 0
printf '%s' "$CMD" | rg -q '\$\{[(=~^]|\$\(<' || exit 0
echo "zsh-expansion: this command uses a zsh-only expansion (\${(f)...}, \${=var}, \$(<file)); Claude Code's parser cannot read it, so it goes to a manual approval. Pass the file path to the script and have the script read the file, or write the arguments out literally." >&2
exit 2
