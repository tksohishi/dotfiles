#!/bin/bash
# Stop hook: refuse to end the turn while a host that hit a bot wall this
# session has neither passed a later rung nor had the last rung
# (patchright-fetch headed) fail nor been recorded in the fetch-blocked site
# map. Reads the per-session state that fetch-blocked-detect.sh writes.
#
# Why: the escalation rule lived in the skill, a PostToolUse reminder, and
# memory, and was still skipped (2026-09-10: USPS tracking reported as
# "bot walled, next rung is headed" instead of being fetched headed; the user
# had said "just try it" several times before). A deterministic gate is the
# only thing that holds.
#
# Escape hatch: record the host in references/sites.md (with the outcome,
# including a CAPTCHA hand-off) and the gate clears — that record is the
# ladder's last rung anyway. Blocks at most twice per session so a genuinely
# stuck flow cannot loop.

input=$(cat)
sid=$(echo "$input" | jq -r '.session_id // empty')
[ -z "$sid" ] && exit 0
state="$HOME/.cache/fetch-blocked/$sid.tsv"
[ -s "$state" ] || exit 0
sites="$HOME/.claude/skills/fetch-blocked/references/sites.md"
counter="$HOME/.cache/fetch-blocked/$sid.gate"
blocks=$(cat "$counter" 2>/dev/null || echo 0)
[ "$blocks" -ge 2 ] && exit 0

pending=""
for host in $(cut -f1 "$state" | sort -u); do
  rg -qiF "$host" "$sites" 2>/dev/null && continue
  rg -q "^$host	passed" "$state" && continue
  rg -q "^$host	blocked	patchright-fetch headed" "$state" && continue
  tried=$(rg "^$host	blocked" "$state" | cut -f3 | sort -u | paste -sd, -)
  pending="$pending $host (tried: $tried);"
done
[ -z "$pending" ] && exit 0

echo $((blocks + 1)) > "$counter"
jq -n --arg r "Fetch ladder not finished for:$pending Do not report these as blocked or say what the next rung would be. Load the fetch-blocked skill and walk the remaining rungs now (agent-browser --headed, then patchright-fetch headed), then record the outcome in references/sites.md. A CAPTCHA hand-off counts as an outcome: record it and the gate clears." '{decision:"block", reason:$r}'
