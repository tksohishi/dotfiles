#!/bin/bash
# Pre-hook: block Bash anti-patterns that bypass dedicated Claude Code tools.
#
# Blocks:
#   1. `cd <dir> && <cmd>`        — working dir is already correct; use absolute
#                                   paths or a separate Bash call.
#   2. `for/while ... do`         — enumerate with Glob/Grep/Read, then one
#                                   Bash call per item. `until` is exempt:
#                                   it is almost always a polling primitive
#                                   (`until <check>; do sleep N; done`),
#                                   not iteration over a collection, so the
#                                   per-operation allowlist concern that
#                                   motivates the loop ban does not apply.
#   3. `head <file>` (not piped)  — use the Read tool with offset/limit.
#   4. `sed -n <range> <file>`    — same; the most common reflex for reading
#                                   a slice of a file. Piping into sed is
#                                   left alone. Bash(sed *) is also in
#                                   permissions.deny as a fallback, but the
#                                   hook fires first and gives the agent an
#                                   instructive "use Read tool" message
#                                   instead of a generic permission denial.
#
# Known limitations / future considerations:
#
# - Quoted strings can false-positive `cd <dir> &&` (the cd-chain rule still
#   uses a loose word boundary). The for/while rule requires both (a) the
#   keyword at a command-segment boundary (^ ; && || |) and (b) a standalone
#   `done` token elsewhere in the command, so quoted message bodies like
#   `git commit -m "wait while X; do Y"` no longer trip it. A
#   `bash -c "for ...; do ...; done"` wrapper would still match (it has
#   real loop syntax inside the wrapper).
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
LOOP_RE='(^|;|&&|\|\||\|)[[:space:]]*(for|while)[[:space:]].+(;|[[:space:]])do([[:space:]]|;|$)'
LOOP_DONE_RE='(^|[[:space:];])done([[:space:];]|$|\))'
HEAD_RE='(^|;|&&|\|\|)[[:space:]]*head[[:space:]]'
SED_READ_RE='(^|;|&&|\|\|)[[:space:]]*sed[[:space:]]+-n[[:space:]]'
EXIT_STATUS_RE='\$\?'

REASON=""

if [[ "$CMD" =~ $CD_CHAIN_RE ]]; then
  REASON="Don't chain 'cd <dir> && <cmd>'. The working directory is already correct; run the command with an absolute path, or cd in a separate Bash call."
elif [[ "$CMD" =~ $LOOP_RE ]] && [[ "$CMD" =~ $LOOP_DONE_RE ]]; then
  REASON="Don't use for/while loops in Bash. Enumerate items with Glob/Grep/Read, then make one Bash call per item. (Polling with 'until cond; do sleep N; done' is allowed.)"
elif [[ "$CMD" =~ $HEAD_RE ]]; then
  REASON="Don't use 'head' to read a file; use the Read tool with offset/limit. Piping into head ('cmd | head -N') is fine; starting a segment with head is blocked."
elif [[ "$CMD" =~ $SED_READ_RE ]]; then
  REASON="Don't use 'sed -n' to read a slice of a file; use the Read tool with offset/limit. The Read tool returns line-numbered output, which is what subsequent Edit calls need anyway. Piping into sed ('cmd | sed -n 5p') is allowed."
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
