#!/bin/bash
# PreToolUse (Claude Edit/Write, Codex apply_patch): refuse lines added to an AGENTS.md or CLAUDE.md that carry a
# date (10/30, 2026-10-30) or a commit hash. Agent instructions state the repo-wide rule as it stands; the incident
# behind it belongs in docs, a postmortem or the commit body. Only added lines are checked, so existing ones stay.

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

is_target() { case "$(basename "$1")" in AGENTS.md|AGENTS.override.md|CLAUDE.md) return 0 ;; esac; return 1; }

case "$TOOL" in
  Edit)
    FILE=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
    is_target "$FILE" || exit 0
    ADDED=$(comm -13 <(jq -r '.tool_input.old_string // ""' <<< "$INPUT" | sort -u) \
                     <(jq -r '.tool_input.new_string // ""' <<< "$INPUT" | sort -u))
    ;;
  Write)
    FILE=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
    is_target "$FILE" || exit 0
    OLD=""
    [ -f "$FILE" ] && OLD=$(cat "$FILE")
    ADDED=$(comm -13 <(printf '%s\n' "$OLD" | sort -u) \
                     <(jq -r '.tool_input.content // ""' <<< "$INPUT" | sort -u))
    ;;
  apply_patch)
    ADDED=$(jq -r '.tool_input.command // ""' <<< "$INPUT" | awk '
      /^\*\*\* (Add|Update) File: / { f = $0; sub(/^\*\*\* (Add|Update) File: /, "", f); n = split(f, p, "/"); on = (p[n] == "AGENTS.md" || p[n] == "AGENTS.override.md" || p[n] == "CLAUDE.md"); next }
      /^\*\*\* Move to: / { f = $0; sub(/^\*\*\* Move to: /, "", f); n = split(f, p, "/"); on = (p[n] == "AGENTS.md" || p[n] == "AGENTS.override.md" || p[n] == "CLAUDE.md"); next }
      /^\*\*\* / { on = 0; next }
      on && /^\+/ { print substr($0, 2) }')
    ;;
  *) exit 0 ;;
esac

[ -n "$ADDED" ] || exit 0

HITS=$(printf '%s\n' "$ADDED" | perl -ne '
  my @h;
  push @h, $1 while /(?<![\d\/.])((?:0?[1-9]|1[0-2])\/(?:0?[1-9]|[12]\d|3[01]))(?![\d\/])/g;
  push @h, $1 while /\b(20\d\d-[01]\d-[0-3]\d)\b/g;
  push @h, grep { /\d/ && /[a-f]/ } /\b([0-9a-f]{7,40})\b/g;
  print join("\n", @h), "\n" if @h;
' | sort -u | head -5 | paste -sd ' ' -)

[ -n "$HITS" ] || exit 0

jq -nc --arg reason "agents-md-no-incidents: the added text carries a date or commit hash ($HITS). AGENTS.md states the rule as it stands now; leave out the dated incident behind it (it belongs in docs, a postmortem or the commit body) and write the rule alone." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
