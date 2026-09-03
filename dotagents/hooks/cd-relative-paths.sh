#!/bin/bash
# Pre-hook: block `cd <dir> && <file tool> <relative path>` chains.
#
# Why: Read() deny rules (the .env / .dev.vars secret-file rules) make Claude
# Code check the file arguments of recognized shell commands. After a `cd`
# it cannot resolve a relative path statically, so it escalates the whole
# command to a permission prompt ("rg on 'X' after a cd would search a
# directory that cannot be determined here, and a Read() deny rule is
# configured"). The fix is to never write that shape: pass absolute paths,
# or use `git -C <dir>`.
#
# Fires only when ALL of these hold:
#   - a segment (split on &&, ;, ||, newline) starts with cd/pushd
#   - a LATER segment (or a pipeline stage inside it) runs one of
#     rg grep cat sed head tail fd ls find
#   - that command has a path-position argument that is not absolute
#     (does not start with /, ~, $HOME, or $PWD)
#
# Not blocked: `cd` alone, `cd X && git -C ...`, absolute paths after a cd,
# and tools with no positional path at all (`cd X && head -30`).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

TOOLS_RE='^(rg|grep|egrep|fgrep|cat|sed|head|tail|fd|ls|find)$'
# Flags that consume the next token, per tool. The value must not be
# mistaken for a path.
VALUE_FLAGS_RE='^(-g|-t|-T|-e|-f|-m|-A|-B|-C|-M|-d|-E|-x|-X|-S|-n|-c|--glob|--type|--type-not|--regexp|--file|--max-count|--after-context|--before-context|--context|--max-columns|--include|--exclude|--exclude-dir|--extension|--max-depth|--min-depth|--expression|--lines|--bytes)$'
# Tools whose first positional is a pattern/script, not a path.
PATTERN_FIRST_RE='^(rg|grep|egrep|fgrep|fd|sed)$'

is_absolute() {
  case "$1" in
    /* | '~' | '~/'* | '$HOME' | '$HOME/'* | '${HOME}'* | '$PWD' | '$PWD/'* | /dev/null) return 0 ;;
  esac
  return 1
}

# Returns 0 and sets OFFENDER if the pipeline stage has a relative path arg.
check_stage() {
  local stage="$1"
  local -a toks=()
  local tok
  # xargs tokenizes shell quotes; unbalanced quotes make it fail -> no tokens.
  while IFS= read -r tok; do toks+=("$tok"); done < <(printf '%s' "$stage" | xargs printf '%s\n' 2>/dev/null)
  [ "${#toks[@]}" -eq 0 ] && return 1

  local i=0
  # Skip env assignments and `command` wrapper.
  while [ $i -lt "${#toks[@]}" ] && [[ "${toks[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= || "${toks[$i]}" == "command" ]]; do
    i=$((i + 1))
  done
  [ $i -ge "${#toks[@]}" ] && return 1
  local tool="${toks[$i]##*/}"
  [[ "$tool" =~ $TOOLS_RE ]] || return 1
  i=$((i + 1))

  local pattern_pending=0
  [[ "$tool" =~ $PATTERN_FIRST_RE ]] && pattern_pending=1
  local dashdash=0
  while [ $i -lt "${#toks[@]}" ]; do
    local t="${toks[$i]}"
    i=$((i + 1))
    if [ $dashdash -eq 0 ]; then
      if [ "$t" = "--" ]; then dashdash=1; continue; fi
      if [[ "$t" =~ $VALUE_FLAGS_RE ]]; then i=$((i + 1)); continue; fi
      [[ "$t" == -* ]] && continue
    fi
    if [ $pattern_pending -eq 1 ]; then pattern_pending=0; continue; fi
    if ! is_absolute "$t"; then
      OFFENDER="$tool $t"
      return 0
    fi
  done
  return 1
}

cd_seen=0
OFFENDER=""
while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  first="${seg%%[[:space:]]*}"
  if [ "$first" = "cd" ] || [ "$first" = "pushd" ]; then
    cd_seen=1
    continue
  fi
  [ $cd_seen -eq 0 ] && continue
  while IFS= read -r stage; do
    if check_stage "$stage"; then break 2; fi
  done < <(printf '%s\n' "$seg" | sed -E 's/\|/\n/g')
done < <(printf '%s\n' "$CMD" | sed -E 's/(&&|\|\||;)/\n/g')

[ -z "$OFFENDER" ] && exit 0

REASON="'$OFFENDER' runs after a cd with a relative path. Claude Code cannot resolve it against the Read() deny rules and escalates the whole command to a permission prompt. Rerun without cd: pass absolute paths (rg <pattern> /abs/dir/file), use git -C <dir> for git, and ls/cat/sed on /abs paths."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
