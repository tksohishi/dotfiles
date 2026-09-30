#!/bin/bash
# Pre-hook: pick the lifetime cap for backgrounded Bash commands.
#
# Claude Code stops a run_in_background command once its `timeout` parameter
# elapses (default 30m, max 2h). This hook raises that parameter for commands
# expected to run longer, via updatedInput.
#
# Cap selection, first match wins:
#   `# bg-timeout: <dur>` anywhere in the command (30m, 90m, 2h, ...)
#   an explicit `timeout` the model already passed                  -> kept
#   dev-server shape (wrangler/vite/next/... dev|serve|watch, runner.ts, snipe) -> 2h
#   everything else                                                 -> Claude's 30m default
# Every cap is clamped to Claude's 2h maximum.

TOOL_INPUT=$(cat)
BG=$(echo "$TOOL_INPUT" | jq -r '.tool_input.run_in_background // false')
[ "$BG" = "true" ] || exit 0

CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')
MAX_MS=7200000
MS=""

SERVER_RE='(^|[[:space:]|&;(])(bun|bunx|pnpm|npm|npx|yarn|deno|node|cargo|go|python3?|uv)?[[:space:]]*(run[[:space:]]+)?(wrangler|vite|next|nuxt|astro|remix|expo|tauri|storybook|nodemon|uvicorn|flask|fastapi|http\.server|serve|dev|start|watch|preview)([[:space:]]|$)|--watch|scripts/runner\.ts|reveal-snipe'
if [[ "$CMD" =~ \#[[:space:]]*bg-timeout:[[:space:]]*([0-9]+)([smhd]?) ]]; then
  N="${BASH_REMATCH[1]}"
  case "${BASH_REMATCH[2]}" in
    m) MS=$((N * 60000)) ;;
    h) MS=$((N * 3600000)) ;;
    d) MS=$((N * 86400000)) ;;
    *) MS=$((N * 1000)) ;;
  esac
elif [ "$(echo "$TOOL_INPUT" | jq -r '.tool_input.timeout // empty')" != "" ]; then
  exit 0
elif [[ "$CMD" =~ $SERVER_RE ]]; then
  MS=$MAX_MS
else
  exit 0
fi
[ "$MS" -gt "$MAX_MS" ] && MS=$MAX_MS

echo "$TOOL_INPUT" | jq -c --argjson ms "$MS" '
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      updatedInput: (.tool_input | .timeout = $ms)
    }
  }'
exit 0
