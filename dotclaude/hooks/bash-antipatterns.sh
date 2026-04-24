#!/bin/bash
# Pre-hook: block Bash anti-patterns that bypass dedicated Claude Code tools.
#
# Blocks:
#   1. `cd <dir> && <cmd>`        — working dir is already correct; use absolute
#                                   paths or a separate Bash call.
#   2. `for/while/until ... do`   — enumerate with Glob/Grep/Read, then one
#                                   Bash call per item.
#   3. `head <file>` (not piped)  — use the Read tool with offset/limit.
#
# Known limitations / future considerations:
#
# - Quoted strings can false-positive. `git commit -m "refactor cd() && cache"`
#   or `echo "for x in …; do …"` inside a quoted argument matches the same
#   regex as the real anti-pattern. Rare; workaround is to write the message
#   to a file and use `git commit -F`.
# - Global scope. Lives in ~/.claude/hooks/, fires in every project. If a
#   project needs different behavior, scope down via that project's
#   .claude/settings.json.
# - Schema drift. `permissionDecision: "deny"` is the current Claude Code hook
#   contract. If the schema changes, this hook silently fails open or closed.
#   Same risk as the other Bash hooks.
# - Scope creep. Resist hookifying every MEMORY.md rule. This hook covers
#   three specific reflexes the user tripped in one session; a similar
#   pattern-of-three threshold should gate future additions.
# - `tail <file>` is not blocked. `tail -f` has a legit shell-only use (log
#   follow) that Read can't replace; add tail only if `tail <file>` becomes
#   a recurring pattern.
# - On hit: Claude sees a deny + reason, rewrites the call. One extra
#   tool-call round-trip per hit. Acceptable.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

CD_CHAIN_RE='(^|[^[:alnum:]_])cd[[:space:]]+[^[:space:]]+[[:space:]]*&&'
LOOP_RE='(^|[^[:alnum:]_])(for|while|until)[[:space:]].+(;|[[:space:]])do([[:space:]]|;|$)'
HEAD_RE='(^|;|&&|\|\|)[[:space:]]*head[[:space:]]'
EXIT_STATUS_RE='\$\?'

REASON=""

if [[ "$CMD" =~ $CD_CHAIN_RE ]]; then
  REASON="Don't chain 'cd <dir> && <cmd>'. The working directory is already correct; run the command with an absolute path, or cd in a separate Bash call."
elif [[ "$CMD" =~ $LOOP_RE ]]; then
  REASON="Don't use for/while/until loops in Bash. Enumerate items with Glob/Grep/Read, then make one Bash call per item."
elif [[ "$CMD" =~ $HEAD_RE ]]; then
  REASON="Don't use 'head' to read a file; use the Read tool with offset/limit. Piping into head ('cmd | head -N') is fine; starting a segment with head is blocked."
elif [[ "$CMD" =~ $EXIT_STATUS_RE ]]; then
  REASON="Don't use \$? in Bash commands. The previous command's exit status is already in the tool result; read it there, and make the follow-up check a separate Bash call."
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
