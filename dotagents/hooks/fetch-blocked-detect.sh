#!/bin/bash
# Post-hook on WebFetch|Bash: when a fetch comes back with a bot-wall
# signature, inject the fetch-blocked escalation instruction right next to the
# failing result. Fires in subagents too (hooks run for every tool call), so a
# delegated researcher gets the ladder at the moment it hits the wall instead
# of improvising and reporting "unreachable".
#
# Why: 2026-09-02 a subagent saw 403s / "Just a moment" / "blocked by network
# security" on reddit + roadtrailrun.com, tried mirrors and search engines,
# and gave up. Both sites opened on the first headed patchright-fetch run.
#
# Bash calls are only inspected when the command itself looks like a fetch
# (URL, httpie, agent-browser, patchright-fetch), so grepping a saved HTML
# dump for "captcha" doesn't trigger it.

TOOL_INPUT=$(cat)
TOOL=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
  printf '%s' "$CMD" | rg -q 'https?://|\bhttps? (GET|POST|HEAD)\b|agent-browser|patchright-fetch|\bcurl\b|\bwget\b' || exit 0
fi

RESP=$(echo "$TOOL_INPUT" | jq -r '.tool_response | if type=="string" then . else tostring end' | head -c 20000)

BLOCK_RE='Just a moment|blocked by network security|Access Denied|Access to this page has been denied|Performing security verification|Pardon Our Interruption|Press (&|&amp;|and) Hold|unable to give you access|Humans only|verify (that )?you are (a )?human|Are you a robot|\b(403 Forbidden|406 Not Acceptable|429 Too Many Requests)\b|HTTP/[0-9.]+ (403|406|429)\b|status(Code)?["=: ]+(403|406|429)\b|unable to fetch|blocked-domains'
printf '%s' "$RESP" | rg -qi "$BLOCK_RE" || exit 0

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "Bot-wall signature detected in this fetch result. Do not retry the same method, do not switch to mirrors or search engines, and do not report the site as unreachable. Load the `fetch-blocked` skill with the Skill tool now, look the hostname up in its site map, and walk its escalation ladder in order to the last rung (`patchright-fetch <url>` headed). Only after that rung fails on a known-good URL may the host be reported as blocked, listing every rung tried."
  }
}'
exit 0
