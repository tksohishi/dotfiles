#!/bin/bash
# Post-hook: inject minimal "Verify: <cmd>" reminder after state-changing Bash
# commands. Output is `additionalContext` (soft hint, not a deny). Goal is to
# nudge the agent to actually run a verify call before claiming the action
# succeeded — addressing the "claim from action alone, never observe result"
# reflex.
#
# Reminders are intentionally short (one line, no preamble). Verbose context
# costs tokens on every matching tool call.
#
# Patterns handled (extend cautiously; each entry runs on every Bash call):
#   - brew install/uninstall/upgrade
#   - rm
#   - git commit / git push
#   - launchctl load / unload
#   - uv python install/uninstall, uv add/remove/sync
#   - defaults write

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

REMINDER=""
LAST_ARG=$(echo "$CMD" | awk '{print $NF}')

if [[ "$CMD" =~ ^[[:space:]]*brew[[:space:]]+(install|uninstall|upgrade) ]]; then
    if [[ "$LAST_ARG" =~ ^- ]] || [[ -z "$LAST_ARG" ]]; then
        REMINDER="Verify: brew list"
    else
        REMINDER="Verify: brew list | grep ${LAST_ARG}"
    fi

elif [[ "$CMD" =~ ^[[:space:]]*rm[[:space:]] ]]; then
    REMINDER="Verify: ls (the rm'd path)"

elif [[ "$CMD" =~ ^[[:space:]]*git[[:space:]]+commit ]]; then
    REMINDER="Verify: git log -1"

elif [[ "$CMD" =~ ^[[:space:]]*git[[:space:]]+push ]]; then
    REMINDER="Verify: git status"

elif [[ "$CMD" =~ ^[[:space:]]*launchctl[[:space:]]+(load|unload)[[:space:]] ]]; then
    PLIST=$(echo "$CMD" | awk '{print $NF}')
    LABEL=$(basename "$PLIST" .plist 2>/dev/null)
    REMINDER="Verify: launchctl list | grep ${LABEL}"

elif [[ "$CMD" =~ ^[[:space:]]*uv[[:space:]]+python[[:space:]]+(install|uninstall) ]]; then
    REMINDER="Verify: uv python list --only-installed"

elif [[ "$CMD" =~ ^[[:space:]]*uv[[:space:]]+(add|remove|sync) ]]; then
    REMINDER="Verify: uv tree"

elif [[ "$CMD" =~ ^[[:space:]]*defaults[[:space:]]+write[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+) ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    KEY="${BASH_REMATCH[2]}"
    REMINDER="Verify: defaults read ${DOMAIN} ${KEY}"
fi

if [ -z "$REMINDER" ]; then
    exit 0
fi

jq -nc --arg ctx "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
