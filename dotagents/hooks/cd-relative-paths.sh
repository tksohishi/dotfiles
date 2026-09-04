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
#   - a segment (split on &&, ;, ||, &, newline) starts with cd/pushd whose
#     target can leave the working tree (absolute, ~, $VAR, `..`, `-`, none).
#     `cd packages/api && ls src/` inside a monorepo is left alone.
#   - a LATER segment (or a pipeline stage inside it) runs one of
#     rg grep cat sed head tail fd ls find
#   - that command has a path-position argument that is not absolute
#     (does not start with /, ~, $HOME, or $PWD)
#
# Not blocked: `cd` alone, `cd X && git -C ...`, absolute paths after a cd,
# and tools with no positional path at all (`cd X && head -30`).
#
# The command is tokenized with a quote-aware scanner (single/double quotes,
# backslashes) so operators inside quoted strings, e.g. the `|` in
# `grep -E 'a|b' file`, do not split stages and hide the path argument.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

TOOLS_RE='^(rg|grep|egrep|fgrep|cat|sed|head|tail|fd|ls|find)$'
# Flags that consume the next token, per tool (so the value is not
# mistaken for a path). Boolean flags like `cat -n`, `tail -f`, `ls -t`,
# `sed -n` must NOT be listed.
value_flags_for() {
  case "$1" in
    rg) echo '^(-g|-t|-T|-e|-f|-m|-A|-B|-C|-M|-d|-E|-r|--glob|--iglob|--type|--type-not|--regexp|--file|--max-count|--after-context|--before-context|--context|--max-columns|--max-depth|--encoding|--replace|--threads|-j)$' ;;
    grep | egrep | fgrep) echo '^(-e|-f|-m|-A|-B|-C|-d|-D|--regexp|--file|--max-count|--after-context|--before-context|--context|--include|--exclude|--exclude-dir|--directories)$' ;;
    sed) echo '^(-e|-f|--expression|--file)$' ;;
    head | tail) echo '^(-n|-c|--lines|--bytes)$' ;;
    fd) echo '^(-e|-t|-E|-d|-x|-X|-S|-o|--extension|--type|--exclude|--max-depth|--min-depth|--exec|--exec-batch|--size|--owner|--threads|-j)$' ;;
    *) echo '^$' ;;
  esac
}
# Tools whose first positional is a pattern/script, not a path, unless
# the pattern was supplied through a flag (rg/grep -e/-f, sed -e/-f).
PATTERN_FIRST_RE='^(rg|grep|egrep|fgrep|fd|sed)$'
PATTERN_FLAG_RE='^(-e|-f|--regexp|--file|--expression)$'

is_absolute() {
  case "$1" in
    /* | '~' | '~/'* | '$HOME' | '$HOME/'* | '${HOME}'* | '$PWD' | '$PWD/'* | /dev/null) return 0 ;;
  esac
  return 1
}

# Tokenize the command. Fills TOKS (text, quotes removed) and KINDS:
# "w" for a word, "o" for an unquoted operator (&&, ||, |, ;, &).
# Newlines and unquoted ( ) act as `;`. A heredoc body is swallowed as
# words; it contains no cd/tool shapes that matter.
TOKS=()
KINDS=()
tokenize() {
  local s="$1" n=${#1} i=0 c cur="" have=0 q=""
  flush() { if [ $have -eq 1 ]; then TOKS+=("$cur"); KINDS+=("w"); fi; cur=""; have=0; }
  while [ $i -lt "$n" ]; do
    c="${s:$i:1}"
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=""
      elif [ "$q" = '"' ] && [ "$c" = '\' ] && [ $((i + 1)) -lt "$n" ]; then i=$((i + 1)); cur+="${s:$i:1}"
      else cur+="$c"; fi
      i=$((i + 1)); continue
    fi
    case "$c" in
      "'" | '"') q="$c"; have=1 ;;
      '\') i=$((i + 1)); cur+="${s:$i:1}"; have=1 ;;
      ' ' | $'\t') flush ;;
      $'\n' | ';' | '(' | ')') flush; TOKS+=(";"); KINDS+=("o") ;;
      '&')
        # `2>&1` and `&>log` are redirect syntax, not a background operator.
        if [[ "$cur" == *[\<\>] || "${s:$((i + 1)):1}" == '>' ]]; then cur+="$c"; have=1
        else
          flush
          if [ "${s:$((i + 1)):1}" = '&' ]; then TOKS+=("&&"); i=$((i + 1)); else TOKS+=("&"); fi
          KINDS+=("o")
        fi ;;
      '|')
        flush
        if [ "${s:$((i + 1)):1}" = '|' ]; then TOKS+=("||"); i=$((i + 1)); else TOKS+=("|"); fi
        KINDS+=("o") ;;
      *) cur+="$c"; have=1 ;;
    esac
    i=$((i + 1))
  done
  flush
}

# Args: tokens of one pipeline stage. Returns 0 and sets OFFENDER if the
# stage runs a file tool with a relative path argument.
check_stage() {
  local -a toks=("$@")
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
  local value_flags_re
  value_flags_re=$(value_flags_for "$tool")
  local dashdash=0
  while [ $i -lt "${#toks[@]}" ]; do
    local t="${toks[$i]}"
    i=$((i + 1))
    if [ $dashdash -eq 0 ]; then
      if [ "$t" = "--" ]; then dashdash=1; continue; fi
      if [[ "$t" =~ $value_flags_re ]]; then
        [[ "$tool" != fd && "$t" =~ $PATTERN_FLAG_RE ]] && pattern_pending=0
        i=$((i + 1))
        continue
      fi
      [[ "$t" == -* ]] && continue
    fi
    # Redirects and heredocs (2>/dev/null, >out, <<EOF, &>log) are not paths.
    # A bare operator (`>`, `2>`, `<<`) consumes the following token too.
    if [[ "$t" =~ ^[0-9]*[\<\>] || "$t" == \&* ]]; then
      [[ "$t" =~ ^[0-9]*[\<\>\&]+$ ]] && i=$((i + 1))
      continue
    fi
    if [ $pattern_pending -eq 1 ]; then pattern_pending=0; continue; fi
    if ! is_absolute "$t"; then
      OFFENDER="$tool $t"
      return 0
    fi
  done
  return 1
}

tokenize "$CMD"

cd_seen=0
OFFENDER=""
stage=()
seg_start=1
end_stage() {
  if [ $seg_start -eq 1 ] && [ "${#stage[@]}" -gt 0 ]; then
    local first="${stage[0]}"
    if [ "$first" = "cd" ] || [ "$first" = "pushd" ]; then
      # Only a cd that can leave the working tree matters: Claude Code
      # resolves `cd packages/api && ls src/` fine (docs: read-only when the
      # target is inside the working directory). Escaping targets: absolute,
      # ~, $VAR, `..` anywhere, `-` (previous dir), or no target (home).
      case "${stage[1]:-}" in
        '' | /* | '~'* | '$'* | -* | *..*) cd_seen=1 ;;
      esac
      stage=()
      return
    fi
  fi
  if [ $cd_seen -eq 1 ] && [ -z "$OFFENDER" ]; then
    check_stage "${stage[@]}"
  fi
  stage=()
}
for ((k = 0; k < ${#TOKS[@]}; k++)); do
  if [ "${KINDS[$k]}" = "o" ]; then
    end_stage
    if [ "${TOKS[$k]}" = "|" ]; then seg_start=0; else seg_start=1; fi
  else
    stage+=("${TOKS[$k]}")
  fi
done
end_stage

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
