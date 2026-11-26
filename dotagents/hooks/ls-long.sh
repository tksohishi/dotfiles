#!/bin/bash
# Pre-hook: deny `ls -l` (and clusters containing l: -la, -lh, -ltr, -ld).
#
# Agents reach for ls -l to read sizes and times, but half of every line is
# permissions, link count, owner and group, which they almost never read: in
# 30 days of transcripts those fields were 49% of all ls -l output. The deny
# message names the narrower command for each need.
#
# Checked per command segment (split on ; & | ( ) and newlines) whose first
# word is ls, gls or /bin/ls. Quoted strings are dropped first so an "ls -l"
# inside an argument doesn't match.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
case "$CMD" in
  *ls*) ;;
  *) exit 0 ;;
esac

HIT=0
while IFS= read -r seg; do
  read -r -a tok <<< "$seg"
  [ ${#tok[@]} -eq 0 ] && continue
  case "${tok[0]}" in
    ls|gls|/bin/ls) ;;
    *) continue ;;
  esac
  for t in "${tok[@]:1}"; do
    [ "$t" = -- ] && break
    case "$t" in
      --format=long|--format=verbose) HIT=1 ;;
      --*) ;;
      -*l*) HIT=1 ;;
    esac
  done
  [ $HIT -eq 1 ] && break
done < <(printf '%s\n' "$CMD" | sed -E "s/\"[^\"]*\"/Q/g; s/'[^']*'/Q/g" | tr ';&|()`' '\n\n\n\n\n\n')

[ $HIT -eq 0 ] && exit 0

REASON="ls -l spends half of each line on permissions, link count, owner and group. Ask only for what you need: names with ls (-A for dotfiles, -t to sort by time, -1 one per line); size and time with stat -f '%z %Sm %N' <files> (stat -f '%z %N' for sizes only); a directory total with du -sh <dir>; a symlink target with readlink <path>; permissions or owner, when they are the question, with stat -f '%Sp %Su:%Sg %N' <files>."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
