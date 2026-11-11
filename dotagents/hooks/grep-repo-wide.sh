#!/bin/bash
# Pre-hook: block repo-wide recursive grep and git grep.
#
# Both ignore .ignore / .rgignore, and grep -r also ignores .gitignore, so a
# search over the whole tree pulls in paths a repo hides from search on
# purpose: docs/archive/ listed in .ignore, stale copies under
# .claude/worktrees/, node_modules. rg skips all of them.
#
# Blocks, per command segment:
#   - grep/egrep/fgrep/ggrep with -r/-R/--recursive whose path operands are
#     missing (and the segment is not fed by a pipe), ".", "./", "*", "./*",
#     or the repo toplevel.
#   - git grep with no revision or pathspec, or only ".", "./", ":/", "*".
#
# Not blocked: searches that name a subdirectory or file (grep -rn x src/,
# git grep x HEAD~3, git grep x -- docs/). Naming an ignored directory
# explicitly is the way to search it on purpose.
#
# Limitations: quoted strings are collapsed to one opaque token, variables
# are not expanded, and options that take a separate argument are only
# recognized in their short form (-e PAT, -A 3) or with "=".

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -z "$CMD" ] && exit 0

case "$CMD" in
  *grep*) ;;
  *) exit 0 ;;
esac

TOP=""
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  TOP=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
fi

# One segment per line, prefixed "P " when fed by a pipe, "S " otherwise.
# Quoted strings become the single token Q so separators inside them don't split.
segments() {
  printf '%s' "$CMD" | awk '
    BEGIN { RS = "\001"; ORS = "" }
    {
      s = $0; n = length(s); out = "S "; q = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1); pv = substr(s, i - 1, 1)
        if (q != "") {
          if (q == "\"" && c == "\\") { i++; continue }
          if (c == q) { q = "" }
          continue
        }
        if (c == "\"" || c == "\x27") { q = c; out = out " Q "; continue }
        if (c == "\\") { i++; out = out " "; continue }
        if (c == "|" && nx == "|") { out = out "\nS "; i++; continue }
        if (c == "|") { out = out "\nP "; if (nx == "&") i++; continue }
        if (c == "&" && nx == "&") { out = out "\nS "; i++; continue }
        if (c == "&" && pv != ">" && pv != "<" && nx != ">") { out = out "\nS "; continue }
        if (c == ";" || c == "(" || c == ")" || c == "{" || c == "}" || c == "`" || c == "\n") { out = out "\nS "; continue }
        out = out c
      }
      print out "\n"
    }'
}

is_root_path() {
  case "$1" in
    .|./|'*'|'./*') return 0 ;;
  esac
  [ -n "$TOP" ] && [ -d "$1" ] || return 1
  [ "$(cd "$1" && pwd -P)" = "$(cd "$TOP" && pwd -P)" ]
}

# Sets HIT to a description when the segment is a repo-wide search.
check_grep() {
  local piped=$1; shift
  local recursive=0 pattern_given=0 skip_next=0 end_opts=0 t
  local operands=()
  for t in "$@"; do
    if [ $skip_next -eq 1 ]; then skip_next=0; continue; fi
    if [ $end_opts -eq 0 ]; then
      case "$t" in
        --) end_opts=1; continue ;;
        --recursive|--dereference-recursive) recursive=1; continue ;;
        --regexp=*|--file=*) pattern_given=1; continue ;;
        --*) continue ;;
        -?*)
          local letters=${t#-} k ch
          for ((k = 0; k < ${#letters}; k++)); do
            ch=${letters:$k:1}
            case "$ch" in
              r|R) recursive=1 ;;
              e|f|m|A|B|C|d|D)
                case "$ch" in e|f) pattern_given=1 ;; esac
                [ $((k + 1)) -eq ${#letters} ] && skip_next=1
                break ;;
            esac
          done
          continue ;;
      esac
    fi
    operands+=("$t")
  done
  [ $recursive -eq 1 ] || return
  [ $pattern_given -eq 1 ] || operands=("${operands[@]:1}")
  if [ ${#operands[@]} -eq 0 ]; then
    [ "$piped" = P ] || HIT="grep -r with no path searches the whole working directory"
    return
  fi
  for t in "${operands[@]}"; do
    is_root_path "$t" && { HIT="grep -r over '$t' searches the whole repo"; return; }
  done
}

check_git_grep() {
  local pattern_given=0 skip_next=0 end_opts=0 t
  local operands=() pathspecs=()
  for t in "$@"; do
    if [ $skip_next -eq 1 ]; then skip_next=0; continue; fi
    if [ $end_opts -eq 1 ]; then pathspecs+=("$t"); continue; fi
    case "$t" in
      --) end_opts=1; continue ;;
      --*) continue ;;
      -?*)
        local letters=${t#-} k ch
        for ((k = 0; k < ${#letters}; k++)); do
          ch=${letters:$k:1}
          case "$ch" in
            e|f|m|A|B|C|O)
              case "$ch" in e|f) pattern_given=1 ;; esac
              [ $((k + 1)) -eq ${#letters} ] && skip_next=1
              break ;;
          esac
        done
        continue ;;
    esac
    operands+=("$t")
  done
  [ $pattern_given -eq 1 ] || operands=("${operands[@]:1}")
  [ ${#operands[@]} -gt 0 ] && return
  for t in "${pathspecs[@]}"; do
    case "$t" in
      .|./|:/|'*') ;;
      *) return ;;
    esac
  done
  HIT="git grep with no revision or narrowing pathspec searches the whole repo"
}

HIT=""
while IFS= read -r line; do
  piped=${line%% *}
  read -r -a tok <<< "${line#? }"
  [ ${#tok[@]} -eq 0 ] && continue
  case "${tok[0]}" in
    grep|egrep|fgrep|ggrep) check_grep "$piped" "${tok[@]:1}" ;;
    git)
      i=1
      while [ $i -lt ${#tok[@]} ]; do
        case "${tok[$i]}" in
          -C|-c|--git-dir|--work-tree|--namespace) i=$((i + 2)) ;;
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      [ "${tok[$i]}" = grep ] && check_git_grep "${tok[@]:$((i + 1))}" ;;
  esac
  [ -n "$HIT" ] && break
done < <(segments)

[ -z "$HIT" ] && exit 0

REASON="$HIT, including paths this repo hides from search on purpose (.ignore entries such as docs/archive/, stale copies under .claude/worktrees/, node_modules). Use rg instead: it recurses by default and honors .gitignore and .ignore. Flags carry over (-n -i -l -w -F -A/-B/-C); --include='*.ts' becomes -g '*.ts' and --exclude-dir=x becomes -g '!x'. To search a hidden directory on purpose, name it as the path."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
