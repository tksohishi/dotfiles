#!/bin/bash
# Pre-hook: one Bash call carries one state-changing step. A permission prompt
# shows the whole command, and a chain such as append + commit + push +
# worktree remove can only be allowed or denied as a whole; a failure midway
# also leaves it unclear which steps ran. Reads, tests and type checks may sit
# beside the one change. A push right after a commit counts with it, and a
# step repeated (rm a && rm b, a push retried after ||) counts once.
#
# A command that changes state is also denied when, with each quoted string and
# heredoc body counted as one character, it is longer than MAX_LEN: the chain
# around the change, not its message or script, is what makes a prompt unreadable.

MAX_LEN=300

TOOL_INPUT=$(cat)
CMD=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0
CWD=$(printf '%s' "$TOOL_INPUT" | jq -r '.cwd // empty')

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

# Heredoc bodies and quoted strings (commit messages, jq programs, sed scripts)
# become placeholders, so their separators and words don't count.
NO_BODY=$(printf '%s' "$CMD" | perl -0pe 's/<<-?\s*([\x27"]?)(\w+)\1([^\n]*)\n.*?\n\s*\2[ \t]*(?=\n|$)/<<H$3/gs')
STRIPPED=$(printf '%s' "$NO_BODY" | perl -0pe "s/\"(?:[^\"\\\\]|\\\\.)*\"/Q/gs; s/'[^']*'/Q/gs")

changes=()
prev=""
while IFS= read -r seg; do
  read -ra tok <<< "$seg"
  [ ${#tok[@]} -gt 0 ] || continue
  # skip env assignments, sudo and command wrappers before the program
  i=0
  while [ $i -lt ${#tok[@]} ] && [[ "${tok[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= || "${tok[$i]}" =~ ^(sudo|command|env|time|nohup|xargs)$ ]]; do i=$((i + 1)); done
  prog="${tok[$i]##*/}"
  rest=("${tok[@]:$((i + 1))}")
  kind=""
  case "$prog" in
    git)
      j=0
      while [ $j -lt ${#rest[@]} ] && [[ "${rest[$j]}" == -* ]]; do
        case "${rest[$j]}" in -C|-c) j=$((j + 1)) ;; esac
        j=$((j + 1))
      done
      sub="${rest[$j]}"
      sub2="${rest[$((j + 1))]}"
      case "$sub" in
        commit|push|merge|rebase|reset|checkout|restore|switch|clean|rm|mv|pull|cherry-pick|revert|am|apply) kind="git $sub" ;;
        stash) [[ "$sub2" =~ ^(list|show)$ ]] || kind="git stash" ;;
        worktree) [[ "$sub2" =~ ^(add|remove|move|prune)$ ]] && kind="git worktree $sub2" ;;
        branch) [[ " ${rest[*]} " =~ \ -(d|D|m|M|-delete|-move)\  ]] && kind="git branch" ;;
        tag) [ -n "$sub2" ] && [[ ! "$sub2" =~ ^(-l|--list|-n)$ ]] && kind="git tag" ;;
      esac
      ;;
    rm|rmdir|trash|mv|cp|ln) kind="$prog" ;;
    sed|gsed|perl) [[ " ${rest[*]} " =~ \ -[a-zA-Z]*i ]] && kind="$prog -i" ;;
    tee) kind="tee" ;;
    brew) [[ "${rest[0]}" =~ ^(install|uninstall|reinstall|upgrade|remove|rm)$ ]] && kind="brew ${rest[0]}" ;;
    gh) [[ "${rest[1]}" =~ ^(create|merge|close|delete|edit|comment|review|reopen|ready|upload)$ ]] && kind="gh ${rest[0]} ${rest[1]}" ;;
  esac
  if [ -z "$kind" ]; then
    for t in "${rest[@]}"; do
      case "$t" in deploy|destroy|undeploy|start|stop|restart) kind="$prog $t"; break ;; esac
    done
  fi
  # a write redirect into a tracked file; scratch output (tmp/, a new file) is not a change to review
  if [ -z "$kind" ] && [[ "$seg" =~ (^|[^0-9\&\<\>])\>\>?[[:space:]]*([^\&[:space:]][^[:space:]]*) ]]; then
    target="${BASH_REMATCH[2]}"
    target="${target/#\~/$HOME}"
    [ -n "$CWD" ] && git -C "$CWD" ls-files --error-unmatch -- "$target" >/dev/null 2>&1 && kind="> $target"
  fi
  if [ -n "$kind" ]; then
    [[ ("$kind" == "git push" && "$prev" == "git commit") || " ${changes[*]} " == *" $kind "* ]] || changes+=("$kind")
  fi
  prev="$kind"
done < <(printf '%s\n' "$STRIPPED" | perl -pe 's/(\&\&|\|\||;|\|)/\n/g')

[ ${#changes[@]} -gt 0 ] || exit 0

if [ ${#changes[@]} -ge 2 ]; then
  list=$(printf '%s, ' "${changes[@]}")
  deny "This command chains ${#changes[@]} state-changing steps (${list%, }). Split it into one change per call; reads and tests may stay beside it. A push right after its commit may share the call."
fi

len=${#STRIPPED}
if [ "$len" -gt "$MAX_LEN" ]; then
  deny "This command changes state and is $len characters long without its quoted strings and heredoc bodies (limit $MAX_LEN), too long to judge at a permission prompt. Shorten it: move a long script into a file, or split off the reads."
fi
exit 0
