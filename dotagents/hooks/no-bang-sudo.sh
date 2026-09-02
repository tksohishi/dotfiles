#!/usr/bin/env bash
# Stop hook: block ending the turn when the final assistant message tells the
# user to run sudo or another interactive command through the in-session `!`
# prefix. `!` runs non-interactively, so password prompts hang or fail; the
# user has to run those in their own terminal.
set -eu
input=$(cat)
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Last assistant text block (the message may be split one content block per line).
last=$(jq -rs 'map(select(.type == "assistant") | .message.content
  | if type == "array" then map(select(.type == "text") | .text) | last // empty
    elif type == "string" then . else empty end)
  | map(select(. != "")) | last // empty' "$transcript" 2>/dev/null || true)
[ -n "$last" ] || exit 0

# Only lines with no stdin supplied (`|` or `<`): piped input makes most of
# these non-interactive (echo "$v" | wrangler secret put NAME). Keep the list
# conservative; extend it only when a false negative actually bites.
pw='sudo|passwd|ssh-add|ssh-keygen|security unlock-keychain|gpg --(gen|full-gen)-key'
login='(gh auth|gcloud auth|docker|npm|vercel|netlify|firebase|flyctl auth|fly auth|op) (login|signin)|wrangler secret put|aws configure'
if echo "$last" | grep -v '[|<]' | grep -Eq "^[[:space:]]*![[:space:]]*(($pw)\\b|.*\\b($login)\\b)"; then
  jq -n '{decision:"block", reason:"The ! prefix runs non-interactively; sudo, password, and login prompts cannot be answered there. Tell the user to run the command in their own terminal instead."}'
fi
exit 0
