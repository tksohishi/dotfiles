#!/bin/bash
# Pre-hook: prompt before an interpreter runs source that does file I/O on a
# .env-family secrets file (.env, .env.<name>, .dev.vars, .prod.vars),
# including code passed inline with -e / --eval / stdin.
#
# The deny rules only cover paths handed to Read/Edit/Write, and
# bash-antipatterns.sh only inspects the shell command line, so
# `bun scripts/x.ts` where x.ts calls readFileSync(".env") slipped past both.
# This hook opens the source the interpreter is about to run and looks for a
# quoted secrets-path literal together with a file I/O call in the same file.
#
# The rule being enforced: the agent may not read or write .env through any
# tool. Print the value and ask the user to paste it.
#
# NOT covered: the path literal living in another module (the import chain is
# not followed), paths assembled without any `.env` literal in the file
# (path.join(dir, name), a filename taken from argv or a config value), and
# source the hook cannot open (a script path holding a variable or a glob,
# inline code from a command substitution). Those pass silently: the hook
# already lets unfollowed imports through, so prompting on every `$DIR/x.ts`
# was noise without a matching gain in coverage.
#
# Codex PreToolUse supports only allow/deny, so "ask" downgrades to "deny"
# there (same detection as bash-antipatterns.sh: Codex includes "model" in
# the hook input, Claude doesn't).
# Fail open: any parse error, missing tool, or unreadable file exits silently.

TOOL_INPUT=$(cat)
CMD=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$CMD" ] || exit 0

# Fast exit: no interpreter word anywhere in the raw command.
if ! [[ "$CMD" =~ (^|[^A-Za-z0-9_-])(bun|node|deno|tsx|ts-node|python3|python|uv)($|[^A-Za-z0-9_-]) ]]; then
  exit 0
fi

command -v rg >/dev/null 2>&1 || exit 0

CWD=$(printf '%s' "$TOOL_INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || CWD="$PWD"

Q='["'"'"'`]'
NQ='[^"'"'"'`]'
# Quoted .env-family path literal. The lookahead drops .env.example and
# friends; process.env and a bare .env in a comment never match because the
# name has to sit inside quotes that close right after it.
PATH_RE="${Q}(${NQ}*/)?\\.(env(\\.(?!(?:example|sample|template)${Q})[A-Za-z0-9_-]+)?|dev\\.vars|prod\\.vars)${Q}"
IO_RE='\b(readFileSync|writeFileSync|appendFileSync|readFile|writeFile|appendFile|open|readTextFile|writeTextFile|read_text|write_text)\s*\(|Bun\.(file|write)\b'

MATCH_LINE=""

# Both patterns must hit in the same source. Sets MATCH_LINE to the first
# secrets-path line ("<n>: <text>") on success.
scan_file() {
  local f="$1" line
  [ -f "$f" ] || return 1
  line=$(rg -P -n -m1 -- "$PATH_RE" "$f" 2>/dev/null) || return 1
  [ -n "$line" ] || return 1
  rg -P -q -- "$IO_RE" "$f" 2>/dev/null || return 1
  MATCH_LINE="${line#"${line%%[![:space:]]*}"}"
  return 0
}

scan_text() {
  local line
  line=$(printf '%s\n' "$1" | rg -P -n -m1 -- "$PATH_RE" 2>/dev/null) || return 1
  [ -n "$line" ] || return 1
  printf '%s\n' "$1" | rg -P -q -- "$IO_RE" 2>/dev/null || return 1
  MATCH_LINE="${line#"${line%%[![:space:]]*}"}"
  return 0
}

RULE='The agent may not read or write .env through any tool. Print the value and ask the user to paste it in.'

emit() {
  local detail="$1" decision reason
  if printf '%s' "$TOOL_INPUT" | jq -e 'has("model")' >/dev/null 2>&1; then
    decision="deny"
    reason="$detail $RULE (Codex hooks cannot prompt, so this is blocked; ask the user to run it if it is legitimate.)"
  else
    decision="ask"
    reason="$detail $RULE"
  fi
  jq -nc --arg d "$decision" --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $d,
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

strip_q() {
  local s="$1"
  s="${s%\"}"; s="${s#\"}"
  s="${s%\'}"; s="${s#\'}"
  printf '%s' "$s"
}

resolve() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$CWD" "$1" ;;
  esac
}

is_interp() {
  case "${1##*/}" in
    bun|node|deno|tsx|ts-node|python|python3|uv) return 0 ;;
  esac
  return 1
}

while IFS= read -r seg; do
  read -ra toks <<< "$seg"
  [ "${#toks[@]}" -gt 0 ] || continue

  # Skip leading VAR=value assignments and prefix words.
  i=0
  while [ "$i" -lt "${#toks[@]}" ]; do
    case "${toks[$i]}" in
      [A-Za-z_]*=*|sudo|time|env) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "${#toks[@]}" ] || continue

  head=$(strip_q "${toks[$i]}")

  # Track `cd` so a later segment resolves its script against the right dir.
  if [ "$head" = "cd" ] && [ $((i + 1)) -lt "${#toks[@]}" ]; then
    d=$(strip_q "${toks[$((i + 1))]}")
    case "$d" in
      ''|*'$'*|-*) ;;
      *) CWD=$(resolve "$d") ;;
    esac
    continue
  fi

  is_interp "$head" || continue

  inline=0
  for t in "${toks[@]:$((i + 1))}"; do
    case "$t" in
      -e|--eval|-p|--print|-c|-) inline=1; break ;;
    esac
  done

  if [ "$inline" -eq 1 ]; then
    if scan_text "$CMD"; then
      emit "Inline code passed to '$head' does file I/O on a .env-family secrets file (match: $MATCH_LINE)."
    fi
  fi

  for t in "${toks[@]:$((i + 1))}"; do
    a=$(strip_q "$t")
    case "$a" in
      *.ts|*.tsx|*.js|*.mjs|*.cjs|*.py) ;;
      *) continue ;;
    esac
    f=$(resolve "$a")
    if scan_file "$f"; then
      emit "$f does file I/O on a .env-family secrets file (first match, line $MATCH_LINE) and is about to be run by '$head'."
    fi
  done
done < <(printf '%s\n' "$CMD" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
