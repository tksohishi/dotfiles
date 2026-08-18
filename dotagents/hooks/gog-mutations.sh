#!/bin/bash
# Pre-hook: force "ask" on gog subcommands that create, modify, or delete
# Google-side state. The auto-mode classifier approves them too readily
# (they look like innocuous CLI calls), and allow rules only cover reads.
#
# Detection is schema-driven, not pattern-driven: tokens are resolved through
# `gog schema`'s command tree (which includes aliases), so `gog calendar new`
# matches via the create alias while `gog gmail search create` (verb as a
# query argument) does not — search is a leaf, so "create" is never treated
# as a subcommand. A static rule list can't do either and goes stale each
# gog release; the schema ships with the installed binary.
#
# The resolved leaf's name+aliases are checked against MUTATION_VERBS below.
# `gog api call` is included: it can invoke arbitrary write methods.
# Fail open: if gog or its schema is unavailable, exit silently — the command
# itself will fail anyway, and a broken hook must not block unrelated work.
#
# Codex PreToolUse supports only allow/deny, so "ask" downgrades to "deny"
# there (same detection as bash-antipatterns.sh: Codex includes "model" in
# the hook input, Claude doesn't).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

case "$CMD" in
  *gog*) ;;
  *) exit 0 ;;
esac

command -v gog >/dev/null 2>&1 || exit 0

# Leaf verbs (canonical names or aliases) that mutate remote state.
MUTATION_VERBS='["create","new","add","invite","update","edit","set","unset","delete","del","rm","remove","send","post","move","transfer","trash","untrash","import","upload","copy","rename","clear","revoke","respond","rsvp","reply","subscribe","unsubscribe","archive","unarchive","restore","append","write","insert","format","share","mkdir","stop","end","submit","abort","prune","modify","batch-modify","replace","setup","reset","rotate","grant","call"]'

SCHEMA=$(gog schema 2>/dev/null) || exit 0
[ -n "$SCHEMA" ] || exit 0

# Strip quoted regions so a gog reference inside a string bound for another
# shell isn't resolved.
CMD_BARE=$(printf '%s' "$CMD" | tr '\n' '\1' | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | tr '\1' '\n')

while IFS= read -r seg; do
  [[ "$seg" =~ (^|[[:space:]])gog([[:space:]]|$) ]] || continue
  # Tokens after `gog`, up to the first flag; skip value-taking global flags
  # placed before the subcommand (-a/--account, --client, --home).
  tokens=$(printf '%s' "$seg" | sed -E 's/^.*(^|[[:space:]])gog([[:space:]]|$)/\2/' )
  # Schema is piped on stdin: it is too large for --argjson (argv limit).
  resolved=$(printf '%s' "$SCHEMA" | jq -r --arg toks "$tokens" --argjson verbs "$MUTATION_VERBS" '
    def matches($tok): .name == $tok or ((.aliases // []) | index($tok) != null);
    ($toks | split(" ") | map(select(length > 0))) as $t
    | {node: .command, i: 0, skip: false, path: []}
    | until(
        .i >= ($t | length) or .node == null;
        . as $s
        | $t[$s.i] as $tok
        | if $s.skip then {node: $s.node, i: ($s.i + 1), skip: false, path: $s.path}
          elif ($tok | test("^(-a|--account|--client|--home)$")) then {node: $s.node, i: ($s.i + 1), skip: true, path: $s.path}
          elif ($tok | startswith("-")) then {node: $s.node, i: ($s.i + 1), skip: false, path: $s.path}
          else (($s.node.subcommands // []) | map(select(matches($tok))) | first) as $next
            | if $next == null then {node: null, i: $s.i, skip: false, path: $s.path}
              else {node: $next, i: ($s.i + 1), skip: false, path: ($s.path + [$next.name])}
              end
          end
      )
    | .path as $p
    | if ($p | length) == 0 then empty
      else ($p | last) as $leaf
        | if ($verbs | index($leaf)) != null then ($p | join(" ")) else empty end
      end
  ' 2>/dev/null)
  if [[ -n "$resolved" ]]; then
    if echo "$TOOL_INPUT" | jq -e 'has("model")' >/dev/null 2>&1; then
      decision="deny"
      reason="'gog $resolved' mutates Google-side state and is blocked in this agent (Codex hooks cannot prompt). Ask the user to run it, or run it from Claude Code where it prompts for confirmation."
    else
      decision="ask"
      reason="'gog $resolved' creates, modifies, or deletes Google-side state (resolved via gog schema). Confirm with the user before running."
    fi
    jq -nc --arg d "$decision" --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: $d,
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done < <(printf '%s\n' "$CMD_BARE" | sed -E 's/(;|&&|\|\||\|)/\n/g')

exit 0
