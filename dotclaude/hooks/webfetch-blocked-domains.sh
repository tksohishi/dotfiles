#!/bin/bash
# Pre-hook: block WebFetch for domains that require agent-browser.
# Reads tool input JSON from stdin, checks URL against blocked domains list.

SCRIPT_DIR="$(dirname "$0")"
BLOCKED_FILE="$SCRIPT_DIR/webfetch-blocked-domains.txt"

TOOL_INPUT=$(cat)
URL=$(echo "$TOOL_INPUT" | jq -r '.tool_input.url')

while IFS= read -r domain; do
  domain=$(echo "$domain" | xargs)
  [ -z "$domain" ] && continue
  [[ "$domain" = \#* ]] && continue
  if echo "$URL" | grep -qi "$domain"; then
    echo "WebFetch blocked for this domain. Use agent-browser to fetch the content." >&2
    exit 2
  fi
done < "$BLOCKED_FILE"

exit 0
