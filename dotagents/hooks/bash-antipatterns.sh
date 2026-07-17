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
#
# Agent-neutral: fires for both Claude and Codex. Quoted regions are stripped
# before matching so the .env reference must be a bare argument, not a byte
# bound for a remote shell (ssh --command, docker exec sh -c, etc.).

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

# Strip quoted regions before matching. Anything inside '...' or "..." is bound
# for a remote shell and isn't subject to the local secrets check.
CMD_BARE=$(printf '%s' "$CMD" | tr '\n' '\1' | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | tr '\1' '\n')

SECRET_READER_RE='(^|;|&&|\|\||\|)[[:space:]]*(rg|grep|cat|sed|head|tail|awk|less|more|strings|bat|xxd|od|nl|tac)[[:space:]]'
SECRET_FILE_RE='\.env([^.a-zA-Z0-9]|$)|\.env\.(local|production|staging|development|test|prod|stage|dev)([^a-zA-Z0-9]|$)|\.dev\.vars([^a-zA-Z0-9]|$)'

if [[ "$CMD_BARE" =~ $SECRET_READER_RE ]] && [[ "$CMD_BARE" =~ $SECRET_FILE_RE ]]; then
  jq -nc --arg reason "Reading .env / .dev.vars files is blocked — they contain secrets (API keys, tokens). For schema, read .env.example. To inspect a value, use an approved redaction script (e.g., scripts/check-env.ts, scripts/redact-env.ts) or surface the specific need to the user. Once secrets are read, treat them as compromised and rotate." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

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
