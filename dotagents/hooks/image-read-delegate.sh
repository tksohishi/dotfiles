#!/bin/bash
# Pre-hook: push image reads out of the main conversation and into a subagent.
#
# Why: adding an image content block invalidates the messages-tier prompt cache
# (tools + system survive, everything after them is re-written at cache-write
# rates). In a long session that is the single most expensive thing an agent can
# do — measured 2026-07-25, one 670K-token session paid ~$204 across 35
# screenshot reads, ~$10 per PNG, independent of the image's own size. The same
# read inside a fresh subagent (~30K context) costs cents.
#
# Subagent detection is verified working (2026-07-27): a subagent's Read of a
# path with no prior denial passed straight through, so one of agent_id /
# agent_type / a /subagents/ transcript_path is present on PreToolUse — even
# though the docs only describe those fields on SubagentStart and SubagentStop.
# Treat that as undocumented and liable to change. The per-path guard below is
# the backstop: any given path is denied at most once per session, so if
# detection ever stops firing, the delegated read costs one retry instead of
# wedging the turn.
#
# Claude-only: Codex has no working subagent delegation to route these to, so
# this hook is wired in dotclaude/settings.json and NOT in dotcodex/hooks.json.

set -eu

STATE_DIR="${CLAUDE_IMAGE_READ_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-image-read-gate}"

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

[ -n "$FILE_PATH" ] || exit 0

# Raster images only. SVG is text, and PDFs are left alone because they are
# routinely read for their text content, not as pictures.
# tr, not ${var,,} — /bin/bash on macOS is 3.2 and has no case expansion.
FILE_PATH_LC=$(printf '%s' "$FILE_PATH" | tr '[:upper:]' '[:lower:]')
case "$FILE_PATH_LC" in
*.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp | *.tif | *.tiff | *.heic | *.heif) ;;
*) exit 0 ;;
esac

# Already inside a subagent — that IS the destination, let it read.
IS_SUBAGENT=$(echo "$TOOL_INPUT" | jq -r '
  if (.agent_id // .agent_type) then "yes"
  elif ((.transcript_path // "") | contains("/subagents/")) then "yes"
  else "no" end')
[ "$IS_SUBAGENT" = "yes" ] && exit 0

# Loop guard. One denial per path per session; after that the read goes through
# regardless of who is asking, so a failed subagent detection costs one retry
# instead of wedging the turn.
SESSION=$(echo "$TOOL_INPUT" | jq -r '.session_id // "nosession"' | tr -c 'A-Za-z0-9_-' '_')
mkdir -p "$STATE_DIR"
SEEN="$STATE_DIR/$SESSION"
PATH_KEY=$(printf '%s' "$FILE_PATH" | shasum -a 256 | cut -d' ' -f1)

if [ -f "$SEEN" ] && grep -qxF "$PATH_KEY" "$SEEN"; then
  exit 0
fi
echo "$PATH_KEY" >>"$SEEN"

jq -nc --arg p "$FILE_PATH" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (
      "Reading \($p) here would add an image block to this conversation, which invalidates the messages-tier prompt cache and re-writes the whole context at cache-write rates (~$10 per image in a large session). Delegate instead: spawn a subagent and have IT read the image, then report back what you need in words. Batch multiple images into one subagent call. If you genuinely need the image in this context, retry the exact same Read — the second attempt is allowed."
    )
  }
}'
exit 0
