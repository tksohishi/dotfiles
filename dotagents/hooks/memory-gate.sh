#!/bin/bash
# Pre-hook on writes to the file-based memory dir (*/memory/*.md). Memory writes are not gated wholesale (user direction
# 2026-07-04): a memory of type user, project or reference with no rule sentence passes. A memory holds what neither code,
# git, docs, skills nor AGENTS.md supply. Denied:
#   1. any other frontmatter type (feedback, memory, none): behaviour rules belong in the relevant skill or the repo's
#      AGENTS.md (Enforcement Hierarchy level 3), never the global AGENTS.md, which the user curates himself. 10/23: a
#      feedback memory told the agent to hand the user a `!` login line the user had said does not work, and 23 of 33
#      files carried `type: memory`, which the old feedback-only check let through.
#   2. a rule sentence in the body of any type: a line that opens with never / always / do not / don't / the user asked
#      or wants / hand the user / propose. Same reason: a rule in memory drifts from the skill that should hold it.
#   3. a config-derivable value (settings.json, config.toml, .zshrc, Brewfile, ghostty config): read the file live.
# The index (MEMORY.md) is exempt from 1 and 2. An Edit whose new_string carries no `type:` line passes check 1 (the file
# already has its type). Override: change the type, move the rule, drop the value.
#
# Claude-only (not wired in dotcodex/config.toml). Reads .content (Write), .new_string (Edit), or the whole command
# (Bash: a heredoc, echo, tee, in-place sed or perl aimed at a memory .md) so all three tools are inspected.

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

if [ "$TOOL_NAME" = "Bash" ]; then
  CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""')
  echo "$CONTENT" | grep -qE '/memory/[^[:space:]"'"'"']*\.md' || exit 0
  echo "$CONTENT" | grep -qE '(>|\btee\b|\bsed\b.*-i|\bperl\b.*-p?i|\b(cp|mv)\b)' || exit 0
  FILE_PATH=$(echo "$CONTENT" | grep -oE '/memory/[^[:space:]"'"'"']*\.md' | head -1)
  FULL=0
else
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
  CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""')
  [[ "$FILE_PATH" =~ /memory/.*\.md$ ]] || exit 0
  [ "$TOOL_NAME" = "Write" ] && FULL=1 || FULL=0
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

INDEX=0; [ "$(basename "$FILE_PATH")" = MEMORY.md ] && INDEX=1

# 1. The type must be user, project or reference; a full write must carry one.
if [ "$INDEX" = 0 ]; then
  TYPE=$(echo "$CONTENT" | grep -E '^[[:space:]]*type:' | head -1 | sed -E 's/^[[:space:]]*type:[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$TYPE" ] && ! [[ "$TYPE" =~ ^(user|project|reference)$ ]]; then
    emit deny "Memory type '$TYPE' blocked: only user, project or reference. A rule on how to work goes in the relevant skill or the repo's AGENTS.md (never the global one); a fact about the system goes in the repo's docs/."
  fi
  if [ "$FULL" = 1 ] && [ -z "$TYPE" ]; then
    emit deny "Memory without a type blocked: the frontmatter needs type: user | project | reference."
  fi
  # 2. A rule sentence in the body.
  if echo "$CONTENT" | grep -v '^[[:space:]]*description:' | grep -qiE '^[[:space:]]*(\*\*[^*]*\*\*[[:space:]]*)?(-[[:space:]]*)?(never|always|do not|don'"'"'t|the user (asked|wants|said)|hand the user|propose) '; then
    emit deny "Memory holds a rule sentence (never / always / do not / the user asked / hand the user / propose). Rules go in the relevant skill or the repo's AGENTS.md; keep the memory to the fact and link the skill."
  fi
fi

# 3. Config-derivable value.
if echo "$CONTENT" | grep -qE 'settings\.json|config\.toml|\.zshrc|Brewfile|ghostty/config' \
   && echo "$CONTENT" | grep -qE '`[A-Za-z0-9_]+[[:space:]]*[:=][[:space:]]*"[^"]+"`|`[A-Za-z0-9_]+`[[:space:]]*(is|=|:)[[:space:]]*`?"[^"]+"'; then
  emit deny "This memory records a value readable live from a config file (settings.json, config.toml, etc.). Config-derivable facts go stale: drop the value and read the file live."
fi

exit 0
