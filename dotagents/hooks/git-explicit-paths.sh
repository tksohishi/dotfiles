#!/bin/bash
# Pre-hook: git add and git commit must name their paths. Denies sweeping
# forms (git add -A/--all/-u/./:/, git commit -a, and git commit without
# `-- <path>...`), so a commit can't pick up files another session or the
# user staged or left modified.
#
# A bare `git commit -m` is denied too, not just `-a`: it commits whatever is
# staged, including paths staged by someone else. `git commit -- <path>`
# commits exactly the named paths regardless of the index.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')

if [[ ! "$CMD" =~ git[[:space:]] ]]; then
  exit 0
fi

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

# Quoted strings (commit messages) become a placeholder so their spaces and
# separators don't split tokens or segments.
STRIPPED=$(printf '%s' "$CMD" | perl -0pe "s/\"(?:[^\"\\\\]|\\\\.)*\"/Q/gs; s/'[^']*'/Q/gs")

while IFS= read -r segment; do
  read -ra tok <<< "$segment"
  i=0
  while [ $i -lt ${#tok[@]} ] && [ "${tok[$i]}" != "git" ]; do i=$((i + 1)); done
  [ $i -lt ${#tok[@]} ] || continue
  i=$((i + 1))
  while [ $i -lt ${#tok[@]} ] && [[ "${tok[$i]}" == -* ]]; do
    case "${tok[$i]}" in -C|-c) i=$((i + 1)) ;; esac
    i=$((i + 1))
  done
  sub="${tok[$i]}"
  args=("${tok[@]:$((i + 1))}")

  case "$sub" in
    add)
      for a in "${args[@]}"; do
        case "$a" in
          -A|--all|-u|--update|--no-ignore-removal|.|./|:/|:/:|'*')
            deny "git add $a stages everything. Name the files: git add <path>..." ;;
        esac
        if [[ "$a" =~ ^-[A-Za-z]+$ && "$a" =~ [Au] ]]; then
          deny "git add $a stages everything. Name the files: git add <path>..."
        fi
      done
      ;;
    commit)
      paths=0
      after=false
      for a in "${args[@]}"; do
        if $after; then
          case "$a" in .|./|:/|:/:|'*') deny "git commit -- $a commits everything. Name the files: git commit -m \"...\" -- <path>..." ;; esac
          paths=$((paths + 1))
          continue
        fi
        case "$a" in
          --) after=true ;;
          --all) deny "git commit --all commits every modified file. Name the files: git commit -m \"...\" -- <path>..." ;;
        esac
        if [[ "$a" =~ ^-[A-Za-z]+$ && "$a" == *a* ]]; then
          deny "git commit $a commits every modified file. Name the files: git commit -m \"...\" -- <path>..."
        fi
      done
      if [ $paths -eq 0 ]; then
        deny "git commit must name its paths so it can't sweep in files someone else staged. Use: git commit -m \"...\" -- <path>... (new files still need git add <path> first)."
      fi
      ;;
  esac
done < <(printf '%s\n' "$STRIPPED" | perl -pe 's/&&|\|\||[;|&\n]/\n/g')

exit 0
