#!/bin/bash
# Pre-hook: block WebFetch for domains that need a different access path.
# Reads tool input JSON from stdin, checks URL hostname against
# webfetch-blocked-domains.txt. Line format:
#   domain[|guidance]   block domain and subdomains; guidance is shown to the agent
#   !domain             exception (allowed); must appear BEFORE the block it carves out
# Full strategy map lives in the fetch-blocked skill.

SCRIPT_DIR="$(dirname "$0")"
BLOCKED_FILE="$SCRIPT_DIR/webfetch-blocked-domains.txt"

TOOL_INPUT=$(cat)
URL=$(echo "$TOOL_INPUT" | jq -r '.tool_input.url')

# Extract lowercase hostname (strip scheme, userinfo, port, path)
HOST=$(echo "$URL" | awk -F/ '{print $3}' | awk -F@ '{print $NF}' | awk -F: '{print $1}' | tr '[:upper:]' '[:lower:]')

DEFAULT_MSG="WebFetch is blocked for this domain. Invoke the fetch-blocked skill for the access strategy."

while IFS= read -r line; do
  case "$line" in '' | \#*) continue ;; esac
  domain="${line%%|*}"
  msg="${line#*|}"
  [ "$msg" = "$line" ] && msg="$DEFAULT_MSG"
  domain=$(echo "$domain" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
  if [[ "$domain" == !* ]]; then
    allow="${domain#!}"
    if [ "$HOST" = "$allow" ] || [[ "$HOST" == *.$allow ]]; then
      exit 0
    fi
    continue
  fi
  if [ "$HOST" = "$domain" ] || [[ "$HOST" == *.$domain ]]; then
    echo "$msg" >&2
    exit 2
  fi
done <"$BLOCKED_FILE"

exit 0
