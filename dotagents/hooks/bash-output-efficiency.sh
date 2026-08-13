#!/bin/bash
# Pre-hook: steer high-frequency commands toward token-lean output forms.
#
# Born from an rtk (rtk-ai/rtk) evaluation, 2026-08-13: rather than install a
# rewrite proxy, enforce the two shapes a 30-transcript tally showed actually
# leak tokens or violate standing rules:
#
#   curl               — 26 of 32 recent curl calls were downloads the standing
#                        rule says to do with httpie (`http --download`) or
#                        WebFetch. Denied whenever a pipeline segment starts
#                        with curl; --help/--version stay allowed. Quoted
#                        regions are stripped first, so `ssh host 'curl ...'`
#                        (remote shell's curl) passes.
#
#   git status / git log — bare forms print long-format output the agent then
#                        reads at full price. `git status` must carry
#                        -s/-sb/--short/--porcelain; `git log` must bound
#                        itself (--oneline, --format/--pretty, --max-count,
#                        -n N, -N) or be piped into head/tail, which bounds
#                        output just as well (git dies on SIGPIPE, so cost is
#                        fine). Global flags (-C <path>, --no-pager, -c k=v)
#                        before the subcommand are tolerated. `git diff` is
#                        deliberately NOT covered: the full diff is often the
#                        legitimate next step after --stat.
#
# Agent-neutral: deny works on both Claude and Codex (Codex PreToolUse has no
# "ask"). Matched per pipeline segment, same conventions as
# bash-antipatterns.sh.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

# Anything inside '...' or "..." is bound for another shell (ssh, docker exec)
# or is data, not a local invocation.
CMD_BARE=$(printf '%s' "$CMD" | tr '\n' '\1' | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | tr '\1' '\n')

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

GIT_GLOBAL_FLAGS='((-C[[:space:]]+[^[:space:]]+|--no-pager|-c[[:space:]]+[^[:space:]]+)[[:space:]]+)*'

while IFS= read -r seg; do
  # curl: httpie/WebFetch are the standing tools; curl only when they can't.
  if [[ "$seg" =~ ^[[:space:]]*curl([[:space:]]|$) ]]; then
    [[ "$seg" =~ [[:space:]]--(help|version)([[:space:]]|$) ]] && continue
    deny "curl is blocked by standing rule: use WebFetch for simple fetches, httpie for API calls ('http METHOD <URL> [flags...]'), and 'http --download GET <URL>' for file downloads. If httpie genuinely cannot do this (e.g. unix sockets), surface that to the user instead of falling back silently."
  fi

  # git status without a short-format flag.
  if [[ "$seg" =~ ^[[:space:]]*git[[:space:]]+${GIT_GLOBAL_FLAGS}status([[:space:]]|$) ]]; then
    if ! [[ "$seg" =~ (^|[[:space:]])(-s[b]?|--short|--porcelain([=[:alnum:]]*)?)([[:space:]]|$) ]]; then
      deny "Bare 'git status' prints long-format output. Use 'git status --short' (or -sb for branch info) per the standing token-efficiency rule."
    fi
  fi

  # git log without a bound. A head/tail pipe elsewhere in the command counts
  # as a bound.
  if [[ "$seg" =~ ^[[:space:]]*git[[:space:]]+${GIT_GLOBAL_FLAGS}log([[:space:]]|$) ]]; then
    if ! [[ "$seg" =~ (^|[[:space:]])(--oneline|--format|--pretty|--max-count|-n[[:space:]]*[0-9]+|-[0-9]+)([=[:space:]]|$) ]] \
       && ! [[ "$CMD_BARE" =~ \|[[:space:]]*(head|tail)([[:space:]]|$) ]]; then
      deny "Unbounded 'git log' prints full-format history. Use 'git log --oneline' (add -n <N> to cap it), or pipe through head, per the standing token-efficiency rule."
    fi
  fi
done < <(printf '%s\n' "$CMD_BARE" | sed -E 's/(;|&&|\|\||\|)/\n/g')

exit 0
