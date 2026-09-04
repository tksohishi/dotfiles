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
#   - a segment (split on &&, ;, ||, &, newline, braces/parens) starts with
#     cd/pushd whose target can leave the working tree (absolute, ~, $VAR,
#     `..`, `-`, none). `cd packages/api && ls src/` in a monorepo is fine.
#   - a LATER segment (or a pipeline stage inside it) runs one of
#     rg grep cat sed head tail fd ls find
#   - that command has a path-position argument that is not absolute
#     (does not start with /, ~, $HOME, or $PWD)
#
# Not blocked: `cd` alone, `cd X && git -C ...`, absolute paths after a cd,
# and tools with no positional path at all (`cd X && head -30`).
#
# The command is tokenized with a quote-aware scanner: single/double/$'..'
# quotes, backslashes, `# comments`, backslash-newline continuations, and
# heredoc bodies (skipped entirely, they are data). Operators inside quoted
# strings, e.g. the `|` in `grep -E 'a|b' file`, never split stages.
#
# Out of scope (an agent does not write these to read a file): backtick
# substitutions, commands inside a `$(...)` that is itself inside double
# quotes, `ca\t`-style split names, `pushd +N`.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

TOOLS_RE='^(rg|grep|egrep|fgrep|cat|sed|head|tail|fd|ls|find)$'
# Wrappers that may precede the tool (or the cd) without changing its args.
PREFIX_RE='^(command|builtin|time|sudo|nice|env|exec|!)$'
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
PATTERN_FLAG_EQ_RE='^(--regexp|--file|--expression)=.'
# Value flags whose argument is itself a file that gets read.
FILE_VALUE_FLAG_RE='^(-f|--file)$'

is_absolute() {
  case "$1" in
    /* | '~' | '~/'* | '$HOME' | '$HOME/'* | '${HOME}'* | '$PWD' | '$PWD/'* | /dev/null) return 0 ;;
  esac
  return 1
}

# Tokenize the command. Fills TOKS (text, quotes removed) and KINDS:
# "w" for a bare word, "q" for a word that was (partly) quoted, "o" for an
# unquoted operator (&&, ||, |, ;, &). Newlines, unquoted ( ), and
# standalone { } act as `;`.
TOKS=()
KINDS=()
tokenize() {
  local s="$1" n=${#1} i=0 c cur="" have=0 quoted=0
  # Quote context stack: ' (single), A ($'..' ANSI-C), " (double),
  # s ($(..) substitution, one entry per open paren). Everything inside any
  # context is appended to the current word verbatim; a $(..) nested inside
  # double quotes is not inspected for cd/tool shapes.
  local -a ctx=()
  local -a heredocs=()
  # True when the innermost open context is a $(...) substitution.
  in_sub() { [ "${#ctx[@]}" -gt 0 ] && [ "${ctx[${#ctx[@]}-1]}" = s ]; }
  flush() {
    if [ $have -eq 1 ]; then TOKS+=("$cur"); if [ $quoted -eq 1 ]; then KINDS+=("q"); else KINDS+=("w"); fi; fi
    cur=""; have=0; quoted=0
  }
  op() { flush; TOKS+=("$1"); KINDS+=("o"); }
  while [ $i -lt "$n" ]; do
    c="${s:$i:1}"
    if [ "${#ctx[@]}" -gt 0 ]; then
      local top="${ctx[${#ctx[@]}-1]}"
      case "$top" in
        "'")
          if [ "$c" = "'" ]; then unset 'ctx[${#ctx[@]}-1]'; in_sub && cur+="$c"
          else cur+="$c"; fi ;;
        A)
          if [ "$c" = "'" ]; then unset 'ctx[${#ctx[@]}-1]'
          elif [ "$c" = '\' ] && [ $((i + 1)) -lt "$n" ]; then i=$((i + 1)); cur+="${s:$i:1}"
          else cur+="$c"; fi ;;
        '"')
          if [ "$c" = '"' ]; then unset 'ctx[${#ctx[@]}-1]'; in_sub && cur+="$c"
          elif [ "$c" = '\' ] && [ $((i + 1)) -lt "$n" ]; then i=$((i + 1)); cur+="${s:$i:1}"
          elif [ "$c" = '$' ] && [ "${s:$((i + 1)):1}" = '(' ]; then ctx+=("s"); cur+='$('; i=$((i + 1))
          else cur+="$c"; fi ;;
        s)
          case "$c" in
            "'") ctx+=("'"); cur+="$c" ;;
            '"') ctx+=('"'); cur+="$c" ;;
            '(') ctx+=("s"); cur+="$c" ;;
            ')') unset 'ctx[${#ctx[@]}-1]'; cur+="$c" ;;
            '\') i=$((i + 1)); cur+="\\${s:$i:1}" ;;
            *) cur+="$c" ;;
          esac ;;
      esac
      i=$((i + 1)); continue
    fi
    case "$c" in
      "'")
        # $'...' ANSI-C quoting: backslash escapes are active inside.
        if [ "$cur" = '$' ]; then cur=""; ctx+=("A"); else ctx+=("'"); fi
        have=1; quoted=1 ;;
      '"') ctx+=('"'); have=1; quoted=1 ;;
      '\')
        i=$((i + 1))
        # Backslash-newline is a line continuation: plain whitespace.
        if [ "${s:$i:1}" = $'\n' ]; then flush; else cur+="${s:$i:1}"; have=1; fi ;;
      '#')
        if [ $have -eq 0 ]; then
          # Comment: drop to end of line (the newline itself is handled below).
          while [ $i -lt "$n" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
          continue
        fi
        cur+="$c" ;;
      ' ' | $'\t' | $'\r') flush ;;
      $'\n')
        op ";"
        # Skip heredoc bodies opened on the line that just ended.
        while [ "${#heredocs[@]}" -gt 0 ]; do
          local delim="${heredocs[0]}" line
          heredocs=("${heredocs[@]:1}")
          i=$((i + 1))
          while [ $i -lt "$n" ]; do
            line="${s:$i}"; line="${line%%$'\n'*}"
            i=$((i + ${#line} + 1))
            [ "${line#"${line%%[![:space:]]*}"}" = "$delim" ] && break
          done
          i=$((i - 1))
        done ;;
      '(')
        # Top-level $(...): drop the `$`, inspect the inner commands as stages.
        [ "$cur" = '$' ] && { cur=""; have=0; }
        op ";" ;;
      '{' | '}')
        # Brace groups need standalone braces; `${VAR}` and `{a,b}` stay words.
        if [ $have -eq 0 ] && [[ "${s:$((i + 1)):1}" =~ ^[[:space:]\;\|\&]?$ ]]; then op ";"; else cur+="$c"; have=1; fi ;;
      ';' | ')') op ";" ;;
      '&')
        # `2>&1` and `&>log` are redirect syntax, not a background operator.
        if [[ "$cur" == *[\<\>] || "${s:$((i + 1)):1}" == '>' ]]; then cur+="$c"; have=1
        elif [ "${s:$((i + 1)):1}" = '&' ]; then op "&&"; i=$((i + 1))
        else op "&"; fi ;;
      '|')
        if [[ "$cur" == *\> ]]; then cur+="$c"   # >| clobber redirect
        elif [ "${s:$((i + 1)):1}" = '|' ]; then op "||"; i=$((i + 1))
        else op "|"; fi ;;
      '<')
        if [ "${s:$((i + 1)):1}" = '<' ] && [ "${s:$((i + 2)):1}" != '<' ] && [[ "$cur" != *\< ]]; then
          # Heredoc: record the delimiter (optional -, optional quotes).
          local j=$((i + 2)) d=""
          [ "${s:$j:1}" = '-' ] && j=$((j + 1))
          while [ "${s:$j:1}" = ' ' ]; do j=$((j + 1)); done
          while [ $j -lt "$n" ] && [[ "${s:$j:1}" != [[:space:]\;\|\&\)] ]]; do d+="${s:$j:1}"; j=$((j + 1)); done
          d="${d//[\"\']/}"
          heredocs+=("$d")
          cur+="<<$d"; have=1; i=$((j - 1)); flush
        else cur+="$c"; have=1; fi ;;
      *) cur+="$c"; have=1 ;;
    esac
    i=$((i + 1))
  done
  flush
}

# Reads STAGE (tokens of one pipeline stage) and STAGE_Q (1 where the token
# was quoted). Returns 0 and sets OFFENDER if the stage runs a file tool
# with a relative path argument.
check_stage() {
  local -a toks=("${STAGE[@]}")
  local i=0
  # Skip env assignments, wrappers (time, sudo, ...) and leading redirects.
  while [ $i -lt "${#toks[@]}" ] && [[ "${toks[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= || "${toks[$i]}" =~ $PREFIX_RE || "${toks[$i]}" =~ ^[0-9]*[\<\>] ]]; do
    [[ "${toks[$i]}" =~ ^[0-9]*[\<\>\&\|]+$ ]] && i=$((i + 1))
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
      # find: paths come first; everything from the first expression
      # operand on (-name, -exec grep ... {} +, !, parens) is not a path.
      [[ "$tool" == find && ( "$t" == -* || "$t" == "!" ) ]] && break
      if [[ "$t" =~ $value_flags_re ]]; then
        [[ "$tool" != fd && "$t" =~ $PATTERN_FLAG_RE ]] && pattern_pending=0
        # `rg -f patterns` / `sed -f script`: the value is a file that is read.
        if [[ "$tool" != fd && "$t" =~ $FILE_VALUE_FLAG_RE ]] && [ $i -lt "${#toks[@]}" ] && ! is_absolute "${toks[$i]}"; then
          OFFENDER="$tool ${toks[$i]}"
          return 0
        fi
        i=$((i + 1))
        continue
      fi
      [[ "$t" =~ $PATTERN_FLAG_EQ_RE ]] && pattern_pending=0
      # BSD `sed -i ''`: the empty suffix is an argument, not a path.
      if [[ "$tool" == sed && "$t" == -i ]] && [ $i -lt "${#toks[@]}" ] && [ -z "${toks[$i]}" ]; then i=$((i + 1)); continue; fi
      [[ "$t" == -* ]] && continue
    fi
    # Redirects: output targets (>out, 2>/dev/null, &>log) are not reads.
    # An input redirect (<file) is a read and must be absolute too.
    # A quoted token like '<title>' is a pattern, never a redirect.
    if [ "${STAGE_Q[$((i - 1))]}" = 0 ] && [[ "$t" =~ ^[0-9]*[\<\>] || "$t" == \&* ]]; then
      local target="${t#[0-9]}"; target="${target#[0-9]}"
      local opchars="${target%%[!<>&|]*}"
      target="${target#"$opchars"}"
      if [ -z "$target" ] && [ $i -lt "${#toks[@]}" ]; then target="${toks[$i]}"; i=$((i + 1)); fi
      if [ "$opchars" = "<" ] && [ -n "$target" ] && ! is_absolute "$target"; then
        OFFENDER="$tool <$target"
        return 0
      fi
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
STAGE=()
STAGE_Q=()
seg_start=1
end_stage() {
  if [ $seg_start -eq 1 ] && [ "${#STAGE[@]}" -gt 0 ]; then
    local j=0
    while [ $j -lt "${#STAGE[@]}" ] && [[ "${STAGE[$j]}" =~ $PREFIX_RE ]]; do j=$((j + 1)); done
    local first="${STAGE[$j]:-}"
    if [ "$first" = "cd" ] || [ "$first" = "pushd" ]; then
      # Only a cd that can leave the working tree matters: Claude Code
      # resolves `cd packages/api && ls src/` fine (docs: read-only when the
      # target is inside the working directory). Escaping targets: absolute,
      # ~, $VAR, `..` anywhere, `-` (previous dir), or no target (home).
      local target="${STAGE[$((j + 1))]:-}"
      [ "$target" = "--" ] && target="${STAGE[$((j + 2))]:-}"
      case "$target" in
        '' | /* | '~'* | '$'* | -* | *..*) cd_seen=1 ;;
      esac
      STAGE=(); STAGE_Q=()
      return
    fi
  fi
  if [ $cd_seen -eq 1 ] && [ -z "$OFFENDER" ] && [ "${#STAGE[@]}" -gt 0 ]; then
    check_stage
  fi
  STAGE=(); STAGE_Q=()
}
for ((k = 0; k < ${#TOKS[@]}; k++)); do
  if [ "${KINDS[$k]}" = "o" ]; then
    end_stage
    if [ "${TOKS[$k]}" = "|" ]; then seg_start=0; else seg_start=1; fi
  else
    STAGE+=("${TOKS[$k]}")
    if [ "${KINDS[$k]}" = "q" ]; then STAGE_Q+=(1); else STAGE_Q+=(0); fi
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
