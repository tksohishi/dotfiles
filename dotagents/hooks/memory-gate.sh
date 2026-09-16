#!/bin/bash
# Pre-hook: deny two narrow classes of writes to the file-based memory dir
# (*/memory/*.md). All other memory writes pass through untouched (user
# direction 2026-07-04: never gate memory writes wholesale).
#   1. type: feedback frontmatter — behavior rules ("don't X", "always Y")
#      belong in the relevant skill or the repo's AGENTS.md, not memory
#      (Enforcement Hierarchy level 3). Never the global AGENTS.md, which the
#      user curates himself.
#   2. Config-derivable values — content asserting a value readable live from a
#      runtime config file (settings.json, config.toml, .zshrc, Brewfile,
#      ghostty config). These go stale; read the file live instead.
#
# Override: drop the value or change the frontmatter type.
#
# Claude-only (not wired in dotcodex/config.toml); Codex does not use this dir.
# Reads .content (Write), .new_string (Edit), or the whole command (Bash: a
# heredoc, echo >, tee, sed -i, perl -pi aimed at a memory .md) so all three
# tools are inspected.

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

if [ "$TOOL_NAME" = "Bash" ]; then
  # A shell write aimed at a memory .md: the command carries the content.
  CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""')
  echo "$CONTENT" | grep -qE '/memory/[^[:space:]"'"'"']*\.md' || exit 0
  echo "$CONTENT" | grep -qE '(>|\btee\b|\bsed\b.*-i|\bperl\b.*-p?i|\b(cp|mv)\b)' || exit 0
else
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
  CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""')
  # Only inspect memory-dir markdown writes (MEMORY.md index included).
  [[ "$FILE_PATH" =~ /memory/.*\.md$ ]] || exit 0
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
if echo "$CONTENT" | grep -qE '^[[:space:]]*type:[[:space:]]*feedback[[:space:]]*$'; then
  emit deny "Feedback-type memory blocked (Enforcement Hierarchy level 3). Put the rule in the relevant skill or the repo's AGENTS.md, not memory. Do not target the global AGENTS.md."
fi

# 2. Config-derivable value -> deny.
# Signature: names a runtime-readable config file AND asserts a key=value literal.
if echo "$CONTENT" | grep -qE 'settings\.json|config\.toml|\.zshrc|Brewfile|ghostty/config' \
   && echo "$CONTENT" | grep -qE '`[A-Za-z0-9_]+[[:space:]]*[:=][[:space:]]*"[^"]+"`|`[A-Za-z0-9_]+`[[:space:]]*(is|=|:)[[:space:]]*`?"[^"]+"'; then
  emit deny "This memory records a value readable live from a config file (settings.json, config.toml, etc.). Config-derivable facts go stale — drop the value and read the file live, or keep only non-derivable guidance."
fi

# Everything else passes through to the normal permission flow.
exit 0
