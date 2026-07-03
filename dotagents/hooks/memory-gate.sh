#!/bin/bash
# Pre-hook: deny two narrow classes of writes to the file-based memory dir
# (*/memory/*.md). All other memory writes pass through untouched (user
# direction 2026-07-04: never gate memory writes wholesale).
#   1. type: feedback frontmatter — behavior rules ("don't X", "always Y")
#      belong in AGENTS.md, not memory (Enforcement Hierarchy level 3).
#   2. Config-derivable values — content asserting a value readable live from a
#      runtime config file (settings.json, config.toml, .zshrc, Brewfile,
#      ghostty config). These go stale; read the file live instead.
#
# Override: drop the value / change the frontmatter type, or put the rule in
# AGENTS.md.
#
# Claude-only (not wired in dotcodex/config.toml); Codex does not use this dir.
# Reads .content (Write) or .new_string (Edit) so both tools are inspected.

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""')

# Only inspect memory-dir markdown writes (MEMORY.md index included).
if [[ ! "$FILE_PATH" =~ /memory/.*\.md$ ]]; then
  exit 0
fi

emit() { # $1=decision $2=reason
  jq -nc --arg d "$1" --arg r "$2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $d,
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# 1. Feedback-type memory -> deny.
if echo "$CONTENT" | head -20 | grep -qE '^[[:space:]]*type:[[:space:]]*feedback[[:space:]]*$'; then
  emit deny "Feedback-type memory blocked (Enforcement Hierarchy level 3). Put the rule in AGENTS.md (project-local, or global ~/.dotfiles/dotagents/AGENTS.md), not memory."
fi

# 2. Config-derivable value -> deny.
# Signature: names a runtime-readable config file AND asserts a key=value literal.
if echo "$CONTENT" | grep -qE 'settings\.json|config\.toml|\.zshrc|Brewfile|ghostty/config' \
   && echo "$CONTENT" | grep -qE '`[A-Za-z0-9_]+[[:space:]]*[:=][[:space:]]*"[^"]+"`|`[A-Za-z0-9_]+`[[:space:]]*(is|=|:)[[:space:]]*`?"[^"]+"'; then
  emit deny "This memory records a value readable live from a config file (settings.json, config.toml, etc.). Config-derivable facts go stale — drop the value and read the file live, or keep only non-derivable guidance."
fi

# Everything else passes through to the normal permission flow.
exit 0
