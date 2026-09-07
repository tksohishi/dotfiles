#!/bin/bash
# Pre-hook: cap the lifetime of every backgrounded Bash command.
#
# The Bash tool's `timeout` parameter only governs the foreground wait; a task
# started with run_in_background (or auto-backgrounded on timeout) has no cap
# at all, and a hung network call or a watch loop that never meets its exit
# condition then lives until the Mac reboots (a GeckoTerminal `http` call sat
# for 2d22h; a reveal watcher waiting for a reveal that never came, 22h).
#
# Rewrites the command to `timeout -k 10 <cap> zsh -c '<command>'` via
# updatedInput. GNU timeout puts itself in its own process group and signals
# the whole group on expiry, so pipeline members and grandchildren die too.
#
# Cap selection, first match wins:
#   `# bg-timeout: <dur>` anywhere in the command (30m, 4h, ...; ceiling 24h)
#   dev-server shape (wrangler/vite/next/... dev|serve|watch, runner.ts, snipe) -> 24h
#   everything else (investigations, polls, watchers)                        -> 30m
#
# Not touched: foreground commands, commands already starting with `timeout`.

TOOL_INPUT=$(cat)
BG=$(echo "$TOOL_INPUT" | jq -r '.tool_input.run_in_background // false')
[ "$BG" = "true" ] || exit 0

CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')
[[ "$CMD" =~ ^[[:space:]]*(g?timeout)[[:space:]] ]] && exit 0

CAP="30m"
SERVER_RE='(^|[[:space:]|&;(])(bun|bunx|pnpm|npm|npx|yarn|deno|node|cargo|go|python3?|uv)?[[:space:]]*(run[[:space:]]+)?(wrangler|vite|next|nuxt|astro|remix|expo|tauri|storybook|nodemon|uvicorn|flask|fastapi|http\.server|serve|dev|start|watch|preview)([[:space:]]|$)|--watch|scripts/runner\.ts|reveal-snipe'
if [[ "$CMD" =~ $SERVER_RE ]]; then CAP="24h"; fi
if [[ "$CMD" =~ \#[[:space:]]*bg-timeout:[[:space:]]*([0-9]+[smhd]?) ]]; then
  CAP="${BASH_REMATCH[1]}"
  SECS=$(echo "$CAP" | sed -E 's/([0-9]+)s?$/\1/; s/([0-9]+)m$/\1*60/; s/([0-9]+)h$/\1*3600/; s/([0-9]+)d$/\1*86400/' | bc)
  [ "$SECS" -gt 86400 ] && CAP="24h"
fi

echo "$TOOL_INPUT" | jq -c --arg cap "$CAP" '
  .tool_input.command as $cmd |
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      updatedInput: (.tool_input | .command = "timeout -k 10 \($cap) zsh -c \($cmd | @sh)")
    }
  }'
exit 0
