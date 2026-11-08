#!/bin/bash
# Pre-hook: block WebFetch for domains that need a different access path.
# Reads tool input JSON from stdin, checks URL hostname against
# webfetch-blocked-domains.local.txt (gitignored, personal hosts) and then
# webfetch-blocked-domains.txt. Line format:
#   domain[|guidance]   block domain and subdomains; guidance is shown to the agent
#   !domain             exception (allowed); must appear BEFORE the block it carves out
# Full strategy map lives in the fetch-blocked skill.

SCRIPT_DIR="$(dirname "$0")"
BLOCKED_FILES=("$SCRIPT_DIR/webfetch-blocked-domains.local.txt" "$SCRIPT_DIR/webfetch-blocked-domains.txt")

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
    rows=$(grep -hF "| $domain " "$SCRIPT_DIR"/../skills/fetch-blocked/references/sites*.md 2>/dev/null)
    if [ "$msg" = "$DEFAULT_MSG" ] && [ -n "$rows" ]; then
      msg="WebFetch blocked. Fetch via this path before citing the page:
$rows"
    fi
    # A denied call never reaches PostToolUse, so fetch-blocked-detect.sh can't record it for fetch-ladder-gate.sh.
    # Only ladder guidance is recorded: a route to another tool (tg, summarize, a login) has no rungs to finish.
    sid=$(echo "$TOOL_INPUT" | jq -r '.session_id // empty')
    if [ -n "$sid" ] && { [ "$msg" = "$DEFAULT_MSG" ] || [[ "$msg" == *httpie* ]]; }; then
      mkdir -p "$HOME/.cache/fetch-blocked"
      printf '%s\tblocked\tWebFetch\n' "${HOST#www.}" >> "$HOME/.cache/fetch-blocked/$sid.tsv"
    fi
    echo "$msg" >&2
    exit 2
  fi
done < <(cat "${BLOCKED_FILES[@]}" 2>/dev/null)

exit 0
