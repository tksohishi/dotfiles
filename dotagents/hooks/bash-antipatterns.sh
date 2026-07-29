#!/bin/bash
# Pre-hook: block Bash commands that read secrets out of .env / .dev.vars files,
# and rg invocations using short -r ("recursive" typo; it's actually --replace).
#
# This is the sole surviving rule from a larger anti-pattern hook. The rest
# (cd-chain, loops, $(...), head/sed reads, bunx, backslash-whitespace, etc.)
# existed only to reshape commands into allowlist-matchable forms so they
# wouldn't trigger permission prompts. Claude now runs in auto mode (a
# classifier gates actions instead of the allowlist) and Codex is relaxed to
# match, so that shaping layer is pure friction and was removed. Secrets
# protection is not allowlist friction, so it stays.
#
#   `> .env*` / `cp x .env*`— commands that write into (or copy out of) .env or
#                           .dev.vars. The agent must not persist values into a
#                           file it is forbidden to read back: it cannot verify
#                           what it wrote and cannot clean up a mistake, so a
#                           bad write becomes the user's manual chore. Hand the
#                           value to the user instead. Covers redirection
#                           (> >> >| >& &>), tee, and the path-argument writers
#                           cp/mv/rsync/ln/install/dd/truncate/sponge (rsync
#                           because AGENTS.md steers the agent to it over cp,
#                           ln because `ln -sf x .env` replaces the file just as
#                           destructively). cp/mv are blocked
#                           on BOTH sides — a secret source exfiltrates into a
#                           file no rule protects — with one exception, a source
#                           named *.example/*.sample/*.template, which keeps
#                           `cp .env.example .env` bootstrapping working.
#                           Irreversible deletion (rm/shred/unlink) is blocked
#                           on the same footing — the agent can't even report
#                           what it destroyed, having never been able to read
#                           it. `trash` stays allowed: it's recoverable from
#                           the Trash, and is the form AGENTS.md already
#                           prefers.
#                           Matched against the raw command, not the
#                           quote-stripped one: a redirection target is the
#                           local shell's regardless of quoting, so
#                           `> "$HOME/.env"` must not slip through.
#                           Not covered: interpreter one-liners that open the
#                           file from inside a quoted script (python -c, node
#                           -e). Blocking those means pattern-matching arbitrary
#                           source in any language; the Write/Edit tool denies
#                           and the risk classifier cover that ground instead.
#
#   `<reader> ... .env*`  — text-reading tools touching .env or .dev.vars.
#                           Use .env.example for schema; redaction scripts for
#                           values. Does not block .env.example (template).
#                           Variants matched: .env, .env.local, .env.production,
#                           .env.staging, .env.development, .env.test,
#                           .env.prod, .env.stage, .env.dev, .dev.vars.
#                           Complements the Read(**/.env) deny rule, which only
#                           covers cat/head/tail/sed; this also catches
#                           rg/grep/awk/strings/xxd/od/nl/tac/less/more/bat.
#                           Doesn't cover bare `env`/`printenv`/`set`.
#                           Matched per pipeline segment: the reader and the
#                           secret path must be in the SAME segment, so
#                           `bun --env-file=.dev.vars x.ts | head` (head reads
#                           bun's stdout, not the file) passes while
#                           `cat .dev.vars | head` still denies.
#
#   *.example/.sample/.template suffixes are exempt everywhere, not just for
#   cp sources: `.dev.vars.example` and `.env.local.example` are schema files,
#   the very alternative the reader deny message recommends. Tokens ending in
#   those suffixes are stripped before matching. Env-specific secret files
#   (`.dev.vars.staging` etc.) still match SECRET_FILE_RE (a dot after
#   `.dev.vars` counts as a boundary) and stay protected — do not widen the
#   exemption beyond the three template suffixes.
#
# Agent-neutral: fires for both Claude and Codex. Quoted regions are stripped
# before matching so the .env reference must be a bare argument, not a byte
# bound for a remote shell (ssh --command, docker exec sh -c, etc.).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

# Strip quoted regions before matching. Anything inside '...' or "..." is bound
# for a remote shell and isn't subject to the local secrets check.
CMD_BARE=$(printf '%s' "$CMD" | tr '\n' '\1' | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | tr '\1' '\n')

SECRET_READER_SEG_RE='^[[:space:]]*(rg|grep|cat|sed|head|tail|awk|less|more|strings|bat|xxd|od|nl|tac)[[:space:]]'
SECRET_FILE_RE='\.env([^.a-zA-Z0-9]|$)|\.env\.(local|production|staging|development|test|prod|stage|dev)([^a-zA-Z0-9]|$)|\.dev\.vars([^a-zA-Z0-9]|$)'

# Drop tokens ending in a template suffix before secret-file matching, so
# `.dev.vars.example` / `.env.local.sample` never count as secret paths.
# Anchored on both sides: the run must be plain path characters (so it cannot
# eat across a redirect operator — `cat .env>.env.example` keeps its `.env`)
# and must END at whitespace/EOL (so `.dev.vars.example.bak` is not a
# template and stays matched).
strip_templates() {
  sed -E 's/[A-Za-z0-9_./~-]*\.(example|sample|template)([[:space:]]|$)/\2/g'
}

# Redirection (> >> >| >& &>) or tee whose target token contains a secret path.
# Runs on $CMD, not $CMD_BARE, so a quoted target stays visible.
SECRET_REDIR_RE='(>>?[|&]?[[:space:]]*|(^|[[:space:];&|(])tee[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)[^[:space:]]*('"$SECRET_FILE_RE"')'

secret_write=""
[[ "$(printf '%s' "$CMD" | strip_templates)" =~ $SECRET_REDIR_RE ]] && secret_write=1

# Writers and destroyers that take the path as a plain argument. Scanned per
# pipeline segment so `echo x | sponge .env` is caught but `rg .env | cp ...`
# noise is not. `trash` is deliberately absent — it is the recoverable escape
# hatch the deny message points at.
if [[ -z "$secret_write" ]]; then
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*(cp|mv|rsync|ln|install|dd|truncate|sponge|rm|shred|unlink)([[:space:]]|$) ]] || continue
    writer="${BASH_REMATCH[1]}"
    read -ra toks <<< "$seg"
    # Bootstrapping from a template is the one legitimate way to create a .env,
    # and only a copier has a source to judge — `rm .env.example .env` must not
    # buy immunity for the second path.
    if [[ "$writer" =~ ^(cp|mv|rsync|ln|install)$ ]]; then
      src=""
      for t in "${toks[@]:1}"; do
        [[ "$t" == -* ]] && continue
        src="$t"
        break
      done
      [[ "$src" =~ \.(example|sample|template)$ ]] && continue
    fi
    for t in "${toks[@]:1}"; do
      [[ "$t" =~ \.(example|sample|template)$ ]] && continue
      if [[ "$t" =~ $SECRET_FILE_RE ]]; then
        secret_write=1
        break 2
      fi
    done
  done < <(printf '%s\n' "$CMD" | sed -E 's/(;|&&|\|\||\|)/\n/g')
fi

if [[ -n "$secret_write" ]]; then
  jq -nc --arg reason "Writing to, copying out of, or deleting .env / .dev.vars is blocked. You cannot read these files back, so you cannot verify what you wrote, undo a mistake, or say what an rm just destroyed. To set a value: print the exact line and ask the user to paste it in. To remove the file: use 'trash <path>', which is recoverable, and confirm with the user first. For a schema change, edit .env.example instead; bootstrapping with 'cp .env.example .env' is still allowed." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

# Reader and secret path must share a pipeline segment: `cat .dev.vars | head`
# denies, `bun --env-file=.dev.vars x.ts | head` (head reads bun's stdout) does
# not.
secret_read=""
while IFS= read -r seg; do
  [[ "$seg" =~ $SECRET_READER_SEG_RE ]] || continue
  # Command substitution can smuggle a path across the textual segment split
  # (`cat $(true | printf .env)`), so a reader segment containing $( or a
  # backtick is matched against the whole command instead — fail closed.
  scope="$seg"
  [[ "$seg" == *'$('* || "$seg" == *'`'* ]] && scope="$CMD_BARE"
  if [[ "$(printf '%s' "$scope" | strip_templates)" =~ $SECRET_FILE_RE ]]; then
    secret_read=1
    break
  fi
done < <(printf '%s\n' "$CMD_BARE" | sed -E 's/(;|&&|\|\||\|)/\n/g')

if [[ -n "$secret_read" ]]; then
  jq -nc --arg reason "Reading .env / .dev.vars files is blocked — they contain secrets (API keys, tokens). For schema, read .env.example. To inspect a value, use an approved redaction script (e.g., scripts/check-env.ts, scripts/redact-env.ts) or surface the specific need to the user. Once secrets are read, treat them as compromised and rotate." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

# Sandbox/config-bypass flags: deterministic port of the interior-wildcard
# deny rules in dotclaude/settings.json (e.g. `codex exec *--dangerously-bypass*`)
# that scripts/sync-allowlist.ts cannot express as Codex prefix_rules. Substring
# match on flag mirrors the `*flag*` wildcard semantics of the source rules.
BYPASS_PAIRS=(
  'codex|--dangerously-bypass'
  'codex|danger-full-access'
  'hermes|--yolo'
  'hermes|--accept-hooks'
  'hermes|--ignore-rules'
  'hermes|--ignore-user-config'
  'agent-browser|--all'
)
for pair in "${BYPASS_PAIRS[@]}"; do
  bin=${pair%%|*}
  flag=${pair#*|}
  bin_re="(^|[[:space:];&|])$bin[[:space:]]"
  if [[ "$CMD_BARE" =~ $bin_re ]] && [[ "$CMD_BARE" == *"$flag"* ]]; then
    jq -nc --arg reason "'$bin' with '$flag' is blocked: it bypasses the agent's sandbox, hooks, or config gates. Run the tool without the bypass flag; if the gate itself is wrong, surface that to the user instead of bypassing it." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done

# `rg` with short -r (alone or bundled, e.g. -rn): almost always a "recursive"
# typo — rg is recursive by default and -r is --replace, which silently rewrites
# the matched text in the output. Intentional replacement must use the long
# --replace form. Scoped per pipeline segment so e.g. `rg -l x | xargs rm -r`
# isn't caught.
while IFS= read -r seg; do
  if [[ "$seg" =~ ^[[:space:]]*rg[[:space:]] ]] && [[ "$seg" =~ (^|[[:space:]])-[a-zA-Z]*r[a-zA-Z]*([[:space:]]|$) ]]; then
    jq -nc --arg reason "rg short -r detected: rg is recursive by DEFAULT; -r is --replace and silently rewrites matched text in the output. Drop the -r (recursion needs no flag). If you really mean replacement, use the explicit long form --replace." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done < <(printf '%s\n' "$CMD_BARE" | sed -E 's/(;|&&|\|\||\|)/\n/g')
exit 0
