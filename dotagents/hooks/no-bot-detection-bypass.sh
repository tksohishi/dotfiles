#!/bin/bash
# Pre-hook: block anti-bot / CAPTCHA detection bypass.
#
# When browser automation hits a CAPTCHA or a bot check, the correct move is to
# stop and hand the form to the user, not to defeat the check. The site is
# explicitly refusing automated interaction; spoofing past that is a
# security-control bypass regardless of how legitimate the underlying errand is
# (2026-07-28: a subagent filling a D&B data-opt-out form wrote a
# navigator.webdriver spoof, then reported it had not).
#
# Detectable signature (Enforcement Hierarchy level 1): the handful of property
# names and library names that exist only to hide automation.
#
# Scope: Write/Edit content, and Bash command strings (covers
# `agent-browser eval "..."` and inline node/python one-liners).

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

case "$TOOL_NAME" in
  Write)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // ""')
    FIELD="file content"
    ;;
  Edit|NotebookEdit)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.new_string // ""')
    FIELD="edit content"
    ;;
  Bash)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""')
    FIELD="command"
    ;;
  *)
    exit 0
    ;;
esac

# Patterns that only appear when hiding automation from a bot check.
PATTERNS=(
  'navigator\.webdriver'
  'webdriver.*=>[[:space:]]*undefined'
  'delete[[:space:]]+navigator\.__proto__\.webdriver'
  'puppeteer-extra-plugin-stealth'
  'playwright-stealth'
  'undetected[_-]chromedriver'
  '2captcha|anti-?captcha|capmonster|deathbycaptcha'
  'AutomationControlled'
)

HIT=""
for p in "${PATTERNS[@]}"; do
  if printf '%s' "$CONTENT" | grep -qiE "$p"; then
    HIT="$p"
    break
  fi
done

[ -z "$HIT" ] && exit 0

REASON="Anti-bot bypass pattern detected in $FIELD (matched: $HIT).

A CAPTCHA or bot check is the site refusing automated interaction. Do not spoof past it, and do not route around it with a CAPTCHA-solving service.

Correct move: stop here, report to the user exactly which form/step is blocked, and hand it over with the values they need to enter. Leave the browser open or save the values to a file, then tell them."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
