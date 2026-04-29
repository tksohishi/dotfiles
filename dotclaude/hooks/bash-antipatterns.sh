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
# - Quoted regions are stripped before pattern matching, so antipatterns
#   inside ssh --command, docker exec sh -c, etc. don't false-positive
#   (and aren't checked at all — those bytes run on a remote shell where
#   our conventions don't apply). Naive stripping doesn't handle escaped
#   quotes (`\"` inside `"..."`) or nested quoting; both are practically
#   non-issues in agent-issued commands. A `bash -c "for ...; do ...; done"`
#   wrapper is now intentionally invisible — same reasoning.
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

# Strip quoted regions before pattern matching. Anything inside '...' or "..."
# is bound for a remote shell (ssh --command, docker exec sh -c, etc.) and
# isn't subject to the local-conventions checks below.
CMD_BARE=$(echo "$CMD" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')

CD_CHAIN_RE='(^|[^[:alnum:]_])cd[[:space:]]+[^[:space:]]+[[:space:]]*&&'
LOOP_RE='(^|;|&&|\|\||\|)[[:space:]]*(for|while)[[:space:]].+(;|[[:space:]])do([[:space:]]|;|$)'
LOOP_DONE_RE='(^|[[:space:];])done([[:space:];]|$|\))'
HEAD_RE='(^|;|&&|\|\|)[[:space:]]*head[[:space:]]'
SED_READ_RE='(^|;|&&|\|\|)[[:space:]]*sed[[:space:]]+-n[[:space:]]'
EXIT_STATUS_RE='\$\?'

REASON=""

if [[ "$CMD_BARE" =~ $CD_CHAIN_RE ]]; then
  REASON="Don't chain 'cd <dir> && <cmd>'. The working directory is already correct; run the command with an absolute path, or cd in a separate Bash call."
elif [[ "$CMD_BARE" =~ $LOOP_RE ]] && [[ "$CMD_BARE" =~ $LOOP_DONE_RE ]]; then
  REASON="Don't use for/while loops in Bash. Enumerate items with Glob/Grep/Read, then make one Bash call per item. (Polling with 'until cond; do sleep N; done' is allowed.)"
elif [[ "$CMD_BARE" =~ $HEAD_RE ]]; then
  REASON="Don't use 'head' to read a file; use the Read tool with offset/limit. Piping into head ('cmd | head -N') is fine; starting a segment with head is blocked."
elif [[ "$CMD_BARE" =~ $SED_READ_RE ]]; then
  REASON="Don't use 'sed -n' to read a slice of a file; use the Read tool with offset/limit. The Read tool returns line-numbered output, which is what subsequent Edit calls need anyway. Piping into sed ('cmd | sed -n 5p') is allowed."
elif [[ "$CMD_BARE" =~ $EXIT_STATUS_RE ]]; then
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
