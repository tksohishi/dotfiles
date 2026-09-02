#!/bin/bash
# Post-hook on WebFetch|Bash: when a fetch comes back with a bot-wall
# signature, inject the fetch-blocked escalation instruction right next to the
# failing result. Fires in subagents too (hooks run for every tool call), so a
# delegated researcher gets the ladder at the moment it hits the wall instead
# of improvising and reporting "unreachable".
#
# It also closes the loop on the skill's site map: every blocked host is
# written to a per-session state file, and when a later fetch of that host
# passes (or the last rung fails) while the host is missing from
# references/sites.md, the hook asks for the row to be written right then.
# Suggest-only by design: which URL was known-good is a judgment the hook
# can't make, so it never edits sites.md itself.
#
# Why: 2026-09-02 a subagent saw 403s / "Just a moment" / "blocked by network
# security" on reddit + roadtrailrun.com, tried mirrors and search engines,
# and gave up. Both sites opened on the first headed patchright-fetch run.
# Same day, pacsun.com was walked to patchright and then reported as "same
# procedure next time" instead of being recorded.
#
# Bash calls are only inspected when the command itself looks like a fetch
# (URL, httpie, agent-browser, patchright-fetch), so grepping a saved HTML
# dump for "captcha" doesn't trigger it.

TOOL_INPUT=$(cat)
TOOL=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty')
SITES="$HOME/.claude/skills/fetch-blocked/references/sites.md"

if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
  # File edits that mention a fetch tool by name (sed into sites.md, git) are not fetches.
  printf '%s' "$CMD" | rg -q '^\s*(sed|git|grep|rg|cat|printf|echo)\b' && exit 0
  printf '%s' "$CMD" | rg -q 'https?://|\bhttps? (GET|POST|HEAD)\b|agent-browser|patchright-fetch|\bcurl\b|\bwget\b' || exit 0
  URL=$(printf '%s' "$CMD" | rg -o 'https?://[^ "'"'"'>)]+' | head -1)
  case "$CMD" in
    *patchright-fetch*) METHOD="patchright-fetch headed" ;;
    *agent-browser*--headed*|*--headed*agent-browser*) METHOD="agent-browser headed" ;;
    *agent-browser*) METHOD="agent-browser headless" ;;
    *) METHOD="httpie" ;;
  esac
elif [ "$TOOL" = "WebFetch" ]; then
  URL=$(echo "$TOOL_INPUT" | jq -r '.tool_input.url // empty')
  METHOD="WebFetch"
else
  exit 0
fi

HOST=$(printf '%s' "$URL" | sed -E 's#^https?://##; s#[/:?].*##; s#^www\.##')

RESP=$(echo "$TOOL_INPUT" | jq -r '.tool_response | if type=="string" then . else tostring end' | head -c 20000)

BLOCK_RE='Just a moment|blocked by network security|Access Denied|Access to this page has been denied|Performing security verification|Pardon Our Interruption|Press (&|&amp;|and) Hold|unable to give you access|Humans only|verify (that )?you are (a )?human|Are you a robot|\b(403 Forbidden|406 Not Acceptable|429 Too Many Requests)\b|HTTP/[0-9.]+ (403|406|429)\b|status(Code)?["=: ]+(403|406|429)\b|unable to fetch|blocked-domains'
BLOCKED=0
printf '%s' "$RESP" | rg -qi "$BLOCK_RE" && BLOCKED=1

SESSION=$(echo "$TOOL_INPUT" | jq -r '.session_id // empty')
STATE_DIR="$HOME/.cache/fetch-blocked"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/${SESSION:-$PPID}.tsv"
touch "$STATE"

REGISTERED=0
[ -n "$HOST" ] && rg -qiF "$HOST" "$SITES" 2>/dev/null && REGISTERED=1

emit() {
  jq -nc --arg ctx "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
  exit 0
}

if [ "$BLOCKED" = 1 ]; then
  [ -n "$HOST" ] && printf '%s\tblocked\t%s\n' "$HOST" "$METHOD" >> "$STATE"
  MSG="Bot-wall signature detected in this fetch result. Do not retry the same method, do not switch to mirrors or search engines, and do not report the site as unreachable. Load the \`fetch-blocked\` skill with the Skill tool now, look the hostname up in its site map, and walk its escalation ladder in order to the last rung (\`patchright-fetch <url>\` headed). Only after that rung fails on a known-good URL may the host be reported as blocked, listing every rung tried."
  if [ -n "$HOST" ] && [ "$REGISTERED" = 0 ]; then
    if [ "$METHOD" = "patchright-fetch headed" ]; then
      FAILED=$(rg "^$HOST\tblocked" "$STATE" | cut -f3 | sort -u | paste -sd, -)
      MSG="Last rung failed for $HOST (failed this session: $FAILED). If the URL was known-good, record the host in references/sites.md as 'No verified path' with the per-method results before continuing."
    else
      MSG="$MSG $HOST is not in references/sites.md: recording the outcome there (which rungs failed, which one passed) is the final step of the ladder, not optional."
    fi
  fi
  emit "$MSG"
fi

# Passed. Worth a note only if this host was blocked earlier this session and is unrecorded.
[ -z "$HOST" ] && exit 0
[ "$REGISTERED" = 1 ] && exit 0
rg -q "^$HOST\tblocked" "$STATE" || exit 0
FAILED=$(rg "^$HOST\tblocked" "$STATE" | cut -f3 | sort -u | paste -sd, -)
printf '%s\tpassed\t%s\n' "$HOST" "$METHOD" >> "$STATE"
emit "$HOST passed via $METHOD after being blocked this session via: $FAILED. It is not in the fetch-blocked skill's references/sites.md. Add a row now (site | what blocks | what works, with today's date), and add the host to dotagents/hooks/webfetch-blocked-domains.txt if WebFetch was among the failures. Then continue the task."
