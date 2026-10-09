#!/bin/bash
# UserPromptSubmit: a /<skill> written mid-message ("まとめて /handoff") is
# not expanded by Claude Code, which treats only a leading slash as a command.
# When the prompt carries such a token and a skill of that name exists on
# disk, tell the model to invoke it through the Skill tool. 10/9: a session
# wrote tmp/handoff-<date>.md by hand instead, and the load hook skipped it.
input=$(cat)
prompt=$(jq -r '.prompt // empty' <<< "$input")
[ -n "$prompt" ] || exit 0
case "$prompt" in /*) exit 0 ;; esac
names=$(grep -oE '(^|[[:space:]])/[a-z][a-z0-9-]*' <<< "$prompt" | sed 's/^[[:space:]]*\///' | sort -u)
[ -n "$names" ] || exit 0
found=""
for n in $names; do
  for d in "$HOME/.claude/skills" "$HOME/.claude/commands" .claude/skills .agents/skills .claude/commands; do
    if [ -d "$d/$n" ] || [ -f "$d/$n.md" ]; then found="$found /$n"; break; fi
  done
done
[ -n "$found" ] || exit 0
jq -n --arg s "${found# }" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: ("The prompt names \($s) mid-message. A slash command is expanded only at the start of a prompt, so it was not loaded: invoke it now with the Skill tool (skill name without the slash), then follow it as if the user had typed it alone.")}}'
