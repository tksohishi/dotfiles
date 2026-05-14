#!/bin/bash
# Pre-hook: block Bash anti-patterns that bypass dedicated Claude Code tools.
#
# Blocks:
#   1. `cd <dir> && <cmd>`        — working dir is already correct; use absolute
#                                   paths or a separate Bash call.
#   2. `for/while ... do`         — even when the body command is allowlisted,
#                                   any `$var` expansion in the body trips
#                                   Claude Code's expansion gate and prompts
#                                   anyway. Practical iteration always uses
#                                   the iter var, so practical loops always
#                                   prompt. Block them upfront and force the
#                                   enumerate-then-per-item pattern, which
#                                   yields literal commands that match
#                                   allowlist rules silently.
#                                   `until` is exempt: it is almost always a
#                                   polling primitive (`until <check>;
#                                   do sleep N; done`), not iteration over a
#                                   collection.
#   3. `head <file>` (not piped)  — use the Read tool with offset/limit.
#   4. `sed -n <range> <file>`    — same; the most common reflex for reading
#                                   a slice of a file. Piping into sed is
#                                   left alone. `Bash(sed *)` is in
#                                   permissions.allow now (was deny) so
#                                   pipe-form sed passes through silently;
#                                   this hook is the sole arbiter for the
#                                   file-read form and gives the "use Read
#                                   tool" hint.
#   4b.`sed -i ...`               — in-place file edit bypasses the Edit
#                                   tool's change tracking and the file
#                                   allowlist. Use Edit for substitutions;
#                                   surface to the user for complex regex
#                                   that Edit can't easily express.
#   5. `$?` in commands           — exit status is already in the tool result;
#                                   make the follow-up check a separate call.
#   6. `gh api`                   — use `gh <resource> <subcommand>` with
#                                   `--json <fields>` instead. Real custom-
#                                   endpoint cases get surfaced to the user
#                                   for approval rather than passing through.
#   7. `<reader> ... .env*`       — text-reading tools touching .env or
#                                   .dev.vars files. Use .env.example for
#                                   schema; redaction scripts for values.
#                                   Does not block .env.example (template).
#                                   Variants matched: .env, .env.local,
#                                   .env.production, .env.staging,
#                                   .env.development, .env.test, .env.prod,
#                                   .env.stage, .env.dev, .dev.vars.
#                                   Doesn't cover bare `env`/`printenv`/`set`
#                                   (different vector; deferred).
#   8. `cp -r/-R/-a` without -n   — recursive cp without no-clobber silently
#                                   overwrites existing files. Earlier the
#                                   redirect target was `cp -an`, but Claude
#                                   Code has a built-in path-safety check for
#                                   cp/mv/rm with flags that prompts even
#                                   when the command is in permissions.allow.
#                                   So `cp -an` still requires manual click.
#                                   Redirect to `rsync -a --ignore-existing
#                                   src/ dst/` instead: same no-clobber
#                                   semantics, auto-approved via the
#                                   `Bash(rsync *)` allow rule because rsync
#                                   is NOT on the built-in path-safety list.
#                                   Trailing slashes on both src and dst copy
#                                   contents into dst (matches `cp -an`
#                                   directory semantics).
#   9. `$(...)` command           — command substitution prompts every time,
#      substitution                  because expansion happens on the local
#                                    shell before the allowlist sees the
#                                    literal command. Run the inner command
#                                    as a separate Bash call (output is in
#                                    the tool result) or use the Read tool
#                                    for file content. Backticks and heredocs
#                                    have the same problem but are added
#                                    only if they recur.
#                                    `$(` inside single quotes
#                                    (e.g. `awk '{print $(NF)}'`) is
#                                    preserved by stripping single-quoted
#                                    regions before matching. Double-quoted
#                                    `"$(...)"` still expands locally and is
#                                    blocked.
#  10. `sqlite3` without          — read-only queries should add -readonly so
#       -readonly                   the database is opened RO at the engine
#                                   level (Bash(sqlite3 -readonly *) is the
#                                   only sqlite3 allow rule). This case
#                                   returns "ask" rather than "deny" so the
#                                   user can approve a one-off mutation in
#                                   the prompt; reads still auto-approve via
#                                   the allow rule, and the message nudges
#                                   the agent to add -readonly so future
#                                   read calls skip the prompt.
#  11. `bunx <bin>` when <bin>    — Bun auto-resolves binaries from
#      is in node_modules/.bin     node_modules/.bin, so `bun <bin>` runs
#                                   the same thing. The typical project-trust
#                                   allow rule is `Bash(bun *)`, while
#                                   `bunx *` would prompt every time.
#                                   Hook fires only when the binary exists
#                                   locally; ad-hoc `bunx some-package` for
#                                   packages not in deps still passes through.
#                                   `bunx tsc` is exempted — the global
#                                   allow rule `Bash(bunx tsc *)` covers
#                                   one-off type-checks against ad-hoc
#                                   `@types/*` installs that the local
#                                   `bun tsc` form can't satisfy.
#  12. `git X && git Y`          — chained git calls. Each git command
#                                   should be a separate Bash tool call so
#                                   each result stays visible and a failure
#                                   mid-chain doesn't obscure context.
#                                   Common offender: `git add ... && git
#                                   commit ... && git push`. Matches &&,
#                                   ;, ||. Narrow scope: only git-then-git
#                                   chains; `git X && <non-git>` is left
#                                   alone (rare in practice, mostly echo
#                                   separators in skill output).
#                                   `cd <dir> && git ...` is caught by #1
#                                   first.
#
# Known limitations / future considerations:
#
# - Quoted regions are stripped before pattern matching, so antipatterns
#   inside ssh --command, docker exec sh -c, etc. don't false-positive
#   (and aren't checked at all — those bytes run on a remote shell where
#   our conventions don't apply). Naive stripping doesn't handle escaped
#   quotes (`\"` inside `"..."`) or nested quoting; both are practically
#   non-issues in agent-issued commands.
# - Global scope. Lives in ~/.claude/hooks/, fires in every project. If a
#   project needs different behavior, scope down via that project's
#   .claude/settings.json.
# - Schema drift. `permissionDecision: "deny"` is the current Claude Code hook
#   contract. If the schema changes, this hook silently fails open or closed.
#   Same risk as the other Bash hooks.
# - Scope creep. Resist hookifying every MEMORY.md rule. This hook covers
#   three specific reflexes the user tripped in one session; a similar
#   pattern-of-three threshold should gate future additions.
# - `tail <file>` is not blocked. `tail -f` has a legit shell-only use (log
#   follow) that Read can't replace; add tail only if `tail <file>` becomes
#   a recurring pattern.
# - On hit: Claude sees a deny + reason, rewrites the call. One extra
#   tool-call round-trip per hit. Acceptable.

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

# Strip quoted regions before pattern matching. Anything inside '...' or "..."
# is bound for a remote shell (ssh --command, docker exec sh -c, etc.) and
# isn't subject to the local-conventions checks below.
# tr to a sentinel byte first so BSD sed treats the whole command as one line
# (multi-line `-m "..."` commit messages would otherwise leak through).
CMD_BARE=$(printf '%s' "$CMD" | tr '\n' '\1' | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | tr '\1' '\n')

# Same idea but strips ONLY single-quoted regions. Used for the $(...) check:
# command substitution expands on the local shell even inside double quotes,
# so we can't strip those, but single quotes do prevent expansion and let
# legitimate uses like awk '{print $(NF)}' through.
CMD_NO_SQ=$(printf '%s' "$CMD" | tr '\n' '\1' | sed "s/'[^']*'//g" | tr '\1' '\n')

CD_CHAIN_RE='(^|[^[:alnum:]_])cd[[:space:]]+[^[:space:]]+[[:space:]]*&&'
LOOP_RE='(^|;|&&|\|\||\|)[[:space:]]*(for|while)[[:space:]].+(;|[[:space:]])do([[:space:]]|;|$)'
LOOP_DONE_RE='(^|[[:space:];])done([[:space:];]|$|\))'
HEAD_RE='(^|;|&&|\|\|)[[:space:]]*head[[:space:]]'
SED_READ_RE='(^|;|&&|\|\|)[[:space:]]*sed[[:space:]]+-n[[:space:]]'
SED_INPLACE_RE='(^|;|&&|\|\||\|)[[:space:]]*sed[[:space:]]+(-i|--in-place)'
EXIT_STATUS_RE='\$\?'
CMD_SUBST_RE='\$\('
GH_API_RE='(^|;|&&|\|\||\|)[[:space:]]*gh[[:space:]]+api([[:space:]]|$)'
SECRET_READER_RE='(^|;|&&|\|\||\|)[[:space:]]*(rg|grep|cat|sed|head|tail|awk|less|more|strings|bat|xxd|od|nl|tac)[[:space:]]'
SECRET_FILE_RE='\.env([^.a-zA-Z0-9]|$)|\.env\.(local|production|staging|development|test|prod|stage|dev)([^a-zA-Z0-9]|$)|\.dev\.vars([^a-zA-Z0-9]|$)'
CP_RECURSIVE_RE='(^|;|&&|\|\||\|)[[:space:]]*cp[[:space:]]+(-[a-zA-Z]*[rRa])'
CP_NOCLOBBER_RE='cp[[:space:]]+([^|;&]*[[:space:]])?-[a-zA-Z]*n'
BUNX_RE='(^|;|&&|\|\||\|)[[:space:]]*bunx[[:space:]]+([^[:space:]]+)'
SQLITE3_RE='(^|;|&&|\|\||\|)[[:space:]]*sqlite3([[:space:]]|$)'
SQLITE3_READONLY_RE='[[:space:]]-readonly([[:space:]]|$)'
GIT_CHAIN_RE='(^|[^[:alnum:]_])git[[:space:]]+[^|;&]*(&&|;|\|\|)[[:space:]]*git[[:space:]]'

REASON=""
DECISION="deny"

if [[ "$CMD_BARE" =~ $CD_CHAIN_RE ]]; then
  REASON="Don't chain 'cd <dir> && <cmd>' — the chained command bypasses the allowlist and triggers a permission prompt. If you need to be in another directory, run 'cd <dir>' as a separate Bash call first (working directory persists across calls), then the command. If you're already in the right place, drop the cd and run the command directly (or with an absolute path)."
elif [[ "$CMD_BARE" =~ $LOOP_RE ]] && [[ "$CMD_BARE" =~ $LOOP_DONE_RE ]]; then
  REASON="Don't use for/while loops in Bash. Even if the body command is allowlisted, any \$var expansion in the body trips Claude Code's expansion gate and prompts anyway — and practical iteration always uses the iter var. Enumerate items first with Glob/Grep/Read, then make one Bash call per item with literal arguments (no \$var) so the calls match allowlist rules silently. Polling with 'until <check>; do sleep N; done' is allowed."
elif [[ "$CMD_BARE" =~ $HEAD_RE ]]; then
  REASON="Don't use 'head' to read a file; use the Read tool with offset/limit. Piping into head ('cmd | head -N') is fine; starting a segment with head is blocked."
elif [[ "$CMD_BARE" =~ $SED_READ_RE ]]; then
  REASON="Don't use 'sed -n' to read a slice of a file; use the Read tool with offset/limit. The Read tool returns line-numbered output, which is what subsequent Edit calls need anyway. Piping into sed ('cmd | sed -n 5p') is allowed."
elif [[ "$CMD_BARE" =~ $SED_INPLACE_RE ]]; then
  REASON="Don't use 'sed -i' (in-place file edit). Use the Edit tool instead — it tracks changes and integrates with file allowlists; sed -i bypasses both. For complex regex replacements that the Edit tool can't easily express, surface to the user before running."
elif [[ "$CMD_BARE" =~ $EXIT_STATUS_RE ]]; then
  REASON="Don't use \$? in Bash commands. The previous command's exit status is already in the tool result; read it there, and make the follow-up check a separate Bash call."
elif [[ "$CMD_NO_SQ" =~ $CMD_SUBST_RE ]]; then
  REASON="Don't use \$(...) command substitution in Bash. It triggers a permission prompt every time, regardless of whether the inner command is allowed, because expansion happens on the local shell before the allowlist sees the literal command. Run the inner command as a separate Bash call (its output is in the tool result), or use the Read tool when reading file content. \$( inside single quotes (e.g. awk '{print \$(NF)}') is unaffected."
elif [[ "$CMD_BARE" =~ $GH_API_RE ]]; then
  REASON="\`gh api\` is blocked. Use \`gh <resource> <subcommand>\` (e.g., \`gh pr view\`, \`gh issue list\`, \`gh release list\`) with \`--json <fields>\` for structured output. Run \`gh <resource> --help\` to find the right subcommand. If you've researched and no subcommand covers this endpoint, surface the specific endpoint to the user for approval before retrying."
elif [[ "$CMD_BARE" =~ $SECRET_READER_RE ]] && [[ "$CMD_BARE" =~ $SECRET_FILE_RE ]]; then
  REASON="Reading .env / .dev.vars files is blocked — they contain secrets (API keys, tokens). For schema, read .env.example. To inspect a value, use an approved redaction script (e.g., scripts/check-env.ts, scripts/redact-env.ts) or surface the specific need to the user. Once secrets are read, treat them as compromised and rotate."
elif [[ "$CMD_BARE" =~ $CP_RECURSIVE_RE ]] && ! [[ "$CMD_BARE" =~ $CP_NOCLOBBER_RE ]]; then
  REASON="Don't use 'cp -r/-R/-a' without -n — recursive cp silently overwrites existing files. Note: 'cp -an' still prompts via Claude Code's built-in path-safety for cp with flags (the allow rule does NOT bypass it). Use 'rsync -a --ignore-existing src/ dst/' instead: same no-clobber semantics, auto-approved via the Bash(rsync *) allow rule because rsync isn't on the path-safety list. Trailing slashes on both src and dst copy contents into dst (matches cp -an directory behavior)."
elif [[ "$CMD_BARE" =~ $SQLITE3_RE ]] && ! [[ "$CMD_BARE" =~ $SQLITE3_READONLY_RE ]]; then
  DECISION="ask"
  REASON="sqlite3 without -readonly. If this is a read query (SELECT, PRAGMA, .schema, .tables, .dump), cancel and retry with -readonly to skip future prompts (the allow rule \`Bash(sqlite3 -readonly *)\` auto-approves that form). If this is a mutation (UPDATE / DELETE / DROP / INSERT / CREATE / ALTER), approve to proceed."
elif [[ "$CMD_BARE" =~ $BUNX_RE ]]; then
  bunx_arg="${BASH_REMATCH[2]}"
  if [[ "$bunx_arg" != "tsc" ]] && [[ "$bunx_arg" != -* ]] && [[ -f "node_modules/.bin/$bunx_arg" ]]; then
    REASON="\`bunx $bunx_arg\` blocked: \`$bunx_arg\` is in node_modules/.bin, so \`bun $bunx_arg\` runs the same binary. Use \`bun $bunx_arg\` so the call matches the typical \`Bash(bun *)\` project-trust allow rule (\`bunx *\` prompts every time). Reserve \`bunx\` for one-off execution of packages not installed locally."
  fi
elif [[ "$CMD_BARE" =~ $GIT_CHAIN_RE ]]; then
  REASON="Don't chain git commands with && / ; / ||. Run each git as a separate Bash tool call so each result stays visible and a failure mid-chain doesn't obscure context. Working directory persists across calls, so \`git add foo && git commit -m bar && git push\` becomes three calls."
fi

if [ -z "$REASON" ]; then
  exit 0
fi

jq -nc --arg reason "$REASON" --arg decision "$DECISION" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: $decision,
    permissionDecisionReason: $reason
  }
}'
exit 0
