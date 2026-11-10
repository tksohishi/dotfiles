#!/usr/bin/env bash
# PostToolUse (Bash) hook: after a `git push` that some workflow runs for,
# record the pushed SHA for this session, which ci-gate.sh (asyncRewake) waits
# on in the background, and tell the agent not to call CI green meanwhile.
set -eu
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
[[ "$cmd" =~ (^|[;&|][[:space:]]*)git[[:space:]]+push ]] || exit 0
cwd=$(echo "$input" | jq -r '.cwd // ""')

# Whether a workflow in $1 runs for a push of the SHA to any branch named in the
# remaining arguments; with no branch names, any push or pull_request trigger
# counts. Reads push.branches / branches-ignore / tags (a tags-only push filter
# never fires for a branch); pull_request counts only when the branch has an
# open PR. push.paths / paths-ignore are matched against CI_GATE_FILES (the
# push's changed files, one per line); with none known, every path counts.
paths_hit() {
  local f kind pat neg inc
  grep -qE '^[px] ' <<< "$1" || return 0
  [ -n "${CI_GATE_FILES:-}" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -q '^p ' <<< "$1"; then inc=0; else inc=1; fi
    while read -r kind pat; do
      neg=0; [[ $pat == '!'* ]] && { neg=1; pat=${pat#!}; }
      [[ $f == $pat ]] || continue
      if [ "$kind" = p ]; then inc=$((1 - neg)); else inc=$neg; fi
    done < <(grep -E '^[px] ' <<< "$1")
    [ "$inc" = 1 ] && return 0
  done <<< "$CI_GATE_FILES"
  return 1
}
workflow_targets() {
  local dir=$1 f spec br kind pat neg hit; shift
  for f in "$dir"/.github/workflows/*.yml "$dir"/.github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    spec=$(awk '
      function strip(s) { gsub(/^[[:space:]"\047]+|[[:space:]"\047]+$/, "", s); return s }
      function emit(k, s,   n, a, i) { gsub(/[][]/, "", s); n = split(s, a, ","); for (i = 1; i <= n; i++) if (strip(a[i]) != "") print k, strip(a[i]) }
      function endpush() { if (ev == "push" && !filt) print "any"; ev = "" }
      /^[[:space:]]*(#|$)/ { next }
      /^("on"|\047on\047|on)[[:space:]]*:/ {
        inon = 1; evind = 0; v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
        if (v ~ /(^|[^a-z_])push([^a-z_]|$)/) print "any"
        if (v ~ /(^|[^a-z_])pull_request([^a-z_]|$)/) print "pr"
        next
      }
      !inon { next }
      /^[^[:space:]]/ { endpush(); inon = 0; next }
      {
        match($0, /^[[:space:]]*/); ind = RLENGTH
        s = substr($0, ind + 1); sub(/[[:space:]]+#.*/, "", s)
        if (!evind) evind = ind
        if (ind <= evind) {
          endpush(); sub(/^-[[:space:]]*/, "", s); key = s; sub(/[[:space:]]*:.*/, "", key)
          if (key == "push") { ev = "push"; filt = 0; lk = "" }
          else if (key == "pull_request") print "pr"
          next
        }
        if (ev != "push") next
        if (s ~ /^-/) { if (lk != "") emit(lk, substr(s, 2)); next }
        key = s; sub(/[[:space:]]*:.*/, "", key); val = s; sub(/^[^:]*:[[:space:]]*/, "", val)
        lk = ""
        if (key == "branches") lk = "b"; else if (key == "branches-ignore") lk = "i"
        else if (key == "paths") lk = "p"; else if (key == "paths-ignore") lk = "x"
        if (key ~ /^(branches|branches-ignore|tags|tags-ignore)$/) filt = 1
        if (lk != "" && val != "") emit(lk, val)
      }
      END { endpush() }
    ' "$f")
    [ -n "$spec" ] || continue
    [ $# -eq 0 ] && return 0
    grep -qx any <<< "$spec" && paths_hit "$spec" && return 0
    for br in "$@"; do
      if grep -qx pr <<< "$spec"; then
        [ "$(cd "$dir" && gh pr list --head "$br" --state open --json number --jq length 2>/dev/null)" != 0 ] && return 0
      fi
      grep -qE '^[bi] ' <<< "$spec" || continue
      if grep -q '^b ' <<< "$spec"; then hit=0; else hit=1; fi
      while read -r kind pat; do
        neg=0; [[ $pat == '!'* ]] && { neg=1; pat=${pat#!}; }
        [[ $br == $pat ]] || continue
        if [ "$kind" = b ]; then hit=$((1 - neg)); else hit=$neg; fi
      done < <(grep -E '^[bi] ' <<< "$spec")
      [ "$hit" = 1 ] && paths_hit "$spec" && return 0
    done
  done
  return 1
}
workflow_targets "$cwd" || exit 0
sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || exit 0
sid=$(echo "$input" | jq -r '.session_id')
dir="${CLAUDE_CI_GATE_DIR:-$HOME/.claude/state/ci-gate}"; mkdir -p "$dir"
branches=$(git -C "$cwd" branch -r --contains "$sha" 2>/dev/null | grep -v -- '->' | sed -E 's#^[[:space:]]*[^/]+/##' || true)
# A rejected or failed push leaves no remote-tracking ref holding the SHA, and no run will ever exist for it: record
# nothing, and drop a marker an earlier attempt at the same SHA left behind.
if [ -z "$branches" ]; then
  [ -f "$dir/$sid.json" ] && [ "$(jq -r '.sha' "$dir/$sid.json")" = "$sha" ] && rm -f "$dir/$sid.json"
  exit 0
fi
# The tracking ref's previous value is the push's before SHA, the base GitHub matches push.paths against.
tracking=$(git -C "$cwd" branch -r --contains "$sha" 2>/dev/null | grep -v -- '->' | sed -E 's#^[[:space:]]*##' | head -1)
CI_GATE_FILES=$(git -C "$cwd" diff --name-only "$tracking@{1}" "$sha" 2>/dev/null || true)
workflow_targets "$cwd" $branches || exit 0
jq -nc --arg cwd "$cwd" --arg sha "$sha" --argjson at "$(date +%s)" '{cwd:$cwd, sha:$sha, pushedAt:$at}' > "$dir/$sid.json"
jq -n --arg c "CI gate: watching Actions runs for ${sha:0:7} in the background. Do not call CI green; a red or unverified result will wake you. Do not poll for it." \
  '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$c}}'
