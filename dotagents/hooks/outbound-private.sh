#!/bin/bash
# Pre-hook: deny any tool call that would send the user's personal strings
# (emails, phone numbers, home address) to an outside service.
#
# The strings live in ~/.claude/outbound-private.txt, outside this public
# repo. Checked:
#   - WebFetch / WebSearch: the whole input.
#   - Bash: the command, when it reaches the network (a URL or a network
#     client token). Commands starting with `gog` pass, since `-a <email>`
#     selects the user's own Google account.
#   - Write / Edit / NotebookEdit: content written to a source file, where a
#     string would go out when the code runs (e.g. a User-Agent header).
#
# When the list is missing (a machine set up without it), the check runs on
# what can be found on the machine: the emails in ~/.gitconfig and
# ~/.gitconfig.local, and the email and phone lines of the pre-commit list
# ~/.claude/private-strings.txt. A home address is not covered then, so the
# user is warned once per session.

TOOL_INPUT=$(cat)
TOOL=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_name // empty')
LIST="$HOME/.claude/outbound-private.txt"

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

NET_RE='https?://|(^|[^[:alnum:]_.-])(curl|wget|http|https|xh|nc|ncat|agent-browser|x-search|ctx7|gh|patchright-fetch)([[:space:]]|$)'

case "$TOOL" in
  WebFetch|WebSearch)
    TEXT=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input | tostring')
    ;;
  Bash)
    TEXT=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
    [[ "$TEXT" =~ ^[[:space:]]*gog[[:space:]] ]] && exit 0
    [[ "$TEXT" =~ $NET_RE ]] || exit 0
    ;;
  Write|Edit|NotebookEdit)
    FILE=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [[ "$FILE" =~ \.(ts|tsx|js|jsx|mjs|cjs|py|sh|swift|go|rb|ipynb)$ ]] || exit 0
    TEXT=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input | [.content, .new_string, .new_source] | map(select(. != null)) | join("\n")')
    ;;
  *)
    exit 0
    ;;
esac

if [ -f "$LIST" ]; then
  ENTRIES=$(cat "$LIST")
else
  ENTRIES=$({ cat "$HOME/.gitconfig" "$HOME/.gitconfig.local" 2>/dev/null | grep -oE '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]+'
    grep -E '@|^[0-9 ()+.-]{7,}$' "$HOME/.claude/private-strings.txt" 2>/dev/null; } | sort -u)
  SESSION=$(printf '%s' "$TOOL_INPUT" | jq -r '.session_id // "none"')
  MARK="${TMPDIR:-/tmp}/outbound-private-warned-$SESSION"
  if [ ! -e "$MARK" ]; then
    WARN="outbound-private: $LIST is missing; checking only the git emails and the email and phone lines of private-strings.txt. Create the list to cover the home address."
  fi
fi

# Compare on letters and digits only, so URL encoding (123+Main),
# slugs and phone separators can't slip a string past.
squash() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'; }
HAYSTACK=$(squash "$TEXT")

while IFS= read -r entry; do
  [[ -z "$entry" || "$entry" == \#* ]] && continue
  needle=$(squash "$entry")
  if [[ -n "$needle" && "$HAYSTACK" == *"$needle"* ]]; then
    deny "This call would send a personal string (\"${entry:0:4}…\") to an outside service. Remove it: no email in User-Agent or headers, for the home address use the public origin in ~/.claude/personal.md (Location). If the user explicitly wants it sent, ask them to do it themselves."
  fi
done <<< "$ENTRIES"

[ -n "${WARN:-}" ] && touch "$MARK" && jq -nc --arg m "$WARN" '{systemMessage: $m}'
exit 0
