#!/usr/bin/env bats

# The bash-antipatterns hook is secrets-only: it denies reader tools
# (rg/grep/cat/sed/head/tail/awk/less/more/strings/bat/xxd/od/nl/tac) that touch
# .env / .dev.vars files, and nothing else (the old command-shaping rules were
# removed on 2026-06-05). The hook always exits 0 and signals a block via a
# permissionDecision:deny JSON payload, so assertions check output, not status.

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/bash-antipatterns.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "denies cat .env" {
  run "$HOOK" <<< "$(bash_input 'cat .env')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies rg reading .env" {
  run "$HOOK" <<< "$(bash_input 'rg SECRET .env')"
  [[ "$output" == *deny* ]]
}

@test "denies grep on .env.local" {
  run "$HOOK" <<< "$(bash_input 'grep KEY .env.local')"
  [[ "$output" == *deny* ]]
}

@test "denies tail on .dev.vars" {
  run "$HOOK" <<< "$(bash_input 'tail .dev.vars')"
  [[ "$output" == *deny* ]]
}

@test "denies less on .env.production" {
  run "$HOOK" <<< "$(bash_input 'less .env.production')"
  [[ "$output" == *deny* ]]
}

@test "allows cat .env.example (template, not a secret)" {
  run "$HOOK" <<< "$(bash_input 'cat .env.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows .environment (not a .env boundary match)" {
  run "$HOOK" <<< "$(bash_input 'cat .environment')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows reader on a non-secret file" {
  run "$HOOK" <<< "$(bash_input 'cat /tmp/foo.txt')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows benign command" {
  run "$HOOK" <<< "$(bash_input 'git status')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows .env inside a quoted remote command (quoted regions stripped)" {
  run "$HOOK" <<< "$(bash_input 'ssh remote "cat .env"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows bare env (not a covered reader; documents the known gap)" {
  run "$HOOK" <<< "$(bash_input 'env')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Per-segment matching: the reader and the secret path must share a pipeline
# segment. A reader consuming another command's stdout is not reading the file.

@test "allows bun --env-file=.dev.vars piped to head (head reads stdout, not the file)" {
  run "$HOOK" <<< "$(bash_input 'bun --env-file=apps/api/.dev.vars scripts/probe.ts 2>&1 | head -12')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows ls .env* piped to grep (grep reads ls output)" {
  run "$HOOK" <<< "$(bash_input 'ls -la eval-lab/.env* golden-set/.env* | grep -v total')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies cat .dev.vars piped to head (same segment as the secret)" {
  run "$HOOK" <<< "$(bash_input 'cat .dev.vars | head -5')"
  [[ "$output" == *deny* ]]
}

@test "denies reader on a secret in a later segment" {
  run "$HOOK" <<< "$(bash_input 'bun run build && grep KEY .env')"
  [[ "$output" == *deny* ]]
}

# Template suffixes are schema files, exempt in every check.

@test "allows cat .dev.vars.example" {
  run "$HOOK" <<< "$(bash_input 'cat apps/api/.dev.vars.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows rg on .env.local.example" {
  run "$HOOK" <<< "$(bash_input 'rg TOKEN_ENC_KEY .env.local.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies cat of template and real secret together" {
  run "$HOOK" <<< "$(bash_input 'cat .env.example .env')"
  [[ "$output" == *deny* ]]
}

@test "denies reader on env-specific .dev.vars.staging (not a template)" {
  run "$HOOK" <<< "$(bash_input 'cat .dev.vars.staging')"
  [[ "$output" == *deny* ]]
}

# Cross-review regressions: holes the first draft of the per-segment /
# template-strip change opened, pinned here so they stay closed.

@test "denies reader with secret smuggled through command substitution" {
  run "$HOOK" <<< "$(bash_input 'cat $(true | printf .env)')"
  [[ "$output" == *deny* ]]
}

@test "denies cat .dev.vars.example.bak (template suffix must end the token)" {
  run "$HOOK" <<< "$(bash_input 'cat .dev.vars.example.bak')"
  [[ "$output" == *deny* ]]
}

@test "denies cat .env>.env.example (template strip must not eat the adjacent secret)" {
  run "$HOOK" <<< "$(bash_input 'cat .env>.env.example')"
  [[ "$output" == *deny* ]]
}

@test "denies double redirect >.env>.env.example" {
  run "$HOOK" <<< "$(bash_input 'echo x >.env>.env.example')"
  [[ "$output" == *deny* ]]
}

# Writes into secret files. Unlike the read rule, these match the raw command:
# a redirection target belongs to the local shell whether or not it's quoted.

@test "denies redirect into .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 > .env')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies append into .env.local" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 >> .env.local')"
  [[ "$output" == *deny* ]]
}

@test "denies redirect with no space before the path" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 >.env')"
  [[ "$output" == *deny* ]]
}

@test "denies clobber-override redirect >| .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 >| .env')"
  [[ "$output" == *deny* ]]
}

@test "denies >& .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 >& .env')"
  [[ "$output" == *deny* ]]
}

@test "denies &> .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 &> .env')"
  [[ "$output" == *deny* ]]
}

@test "denies heredoc write into .env" {
  run "$HOOK" <<< "$(bash_input 'cat > .env <<EOF')"
  [[ "$output" == *deny* ]]
}

@test "denies redirect into a quoted target" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 > "$HOME/app/.env"')"
  [[ "$output" == *deny* ]]
}

@test "denies redirect into a nested .env.production" {
  run "$HOOK" <<< "$(bash_input 'printf x > apps/web/.env.production')"
  [[ "$output" == *deny* ]]
}

@test "denies redirect into .dev.vars" {
  run "$HOOK" <<< "$(bash_input 'echo x > .dev.vars')"
  [[ "$output" == *deny* ]]
}

@test "denies tee .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 | tee .env')"
  [[ "$output" == *deny* ]]
}

@test "denies tee -a .env" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 | tee -a .env')"
  [[ "$output" == *deny* ]]
}

@test "denies tee with a quoted target" {
  run "$HOOK" <<< "$(bash_input 'echo KEY=1 | tee "$HOME/.env"')"
  [[ "$output" == *deny* ]]
}

@test "denies cp into .env" {
  run "$HOOK" <<< "$(bash_input 'cp generated.txt .env')"
  [[ "$output" == *deny* ]]
}

@test "denies mv into .env" {
  run "$HOOK" <<< "$(bash_input 'mv generated.txt .env')"
  [[ "$output" == *deny* ]]
}

@test "denies cp out of .env (exfiltration into an unprotected file)" {
  run "$HOOK" <<< "$(bash_input 'cp .env /tmp/backup.txt')"
  [[ "$output" == *deny* ]]
}

@test "denies cp .env .env.example (would publish secrets to the template)" {
  run "$HOOK" <<< "$(bash_input 'cp .env .env.example')"
  [[ "$output" == *deny* ]]
}

@test "denies dd of=.env" {
  run "$HOOK" <<< "$(bash_input 'dd if=/dev/null of=.env')"
  [[ "$output" == *deny* ]]
}

@test "denies truncate on .env" {
  run "$HOOK" <<< "$(bash_input 'truncate -s 0 .env')"
  [[ "$output" == *deny* ]]
}

@test "denies sponge .env" {
  run "$HOOK" <<< "$(bash_input 'cat in | sponge .env')"
  [[ "$output" == *deny* ]]
}

@test "denies rm .env (unrecoverable; trash is the allowed form)" {
  run "$HOOK" <<< "$(bash_input 'rm .env')"
  [[ "$output" == *deny* ]]
}

@test "denies rm -f .env.local" {
  run "$HOOK" <<< "$(bash_input 'rm -f .env.local')"
  [[ "$output" == *deny* ]]
}

@test "denies shred .env" {
  run "$HOOK" <<< "$(bash_input 'shred -u .env')"
  [[ "$output" == *deny* ]]
}

@test "denies unlink .env" {
  run "$HOOK" <<< "$(bash_input 'unlink .env')"
  [[ "$output" == *deny* ]]
}

@test "denies rm .env.example .env (template source buys no immunity for rm)" {
  run "$HOOK" <<< "$(bash_input 'rm .env.example .env')"
  [[ "$output" == *deny* ]]
}

@test "allows trash .env (recoverable from the Trash)" {
  run "$HOOK" <<< "$(bash_input 'trash .env')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows rm on a non-secret path" {
  run "$HOOK" <<< "$(bash_input 'rm -rf node_modules')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows rm .env.example" {
  run "$HOOK" <<< "$(bash_input 'rm .env.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows rm .dev.vars.example (template suffix exempt for writers too)" {
  run "$HOOK" <<< "$(bash_input 'rm apps/api/.dev.vars.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows redirect into .dev.vars.example" {
  run "$HOOK" <<< "$(bash_input 'printf KEY=\n > .dev.vars.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies redirect into .dev.vars.staging (env-specific, not a template)" {
  run "$HOOK" <<< "$(bash_input 'echo x > .dev.vars.staging')"
  [[ "$output" == *deny* ]]
}

@test "denies rsync into .env (AGENTS.md steers the agent to rsync over cp)" {
  run "$HOOK" <<< "$(bash_input 'rsync -a generated.txt .env')"
  [[ "$output" == *deny* ]]
}

@test "denies ln -sf over .env" {
  run "$HOOK" <<< "$(bash_input 'ln -sf /tmp/fake .env')"
  [[ "$output" == *deny* ]]
}

@test "allows rsync between non-secret dirs" {
  run "$HOOK" <<< "$(bash_input 'rsync -a --ignore-existing src/ dst/')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp .env.example .env (bootstrapping from a template)" {
  run "$HOOK" <<< "$(bash_input 'cp .env.example .env')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp -n .env.sample .env (flags skipped when finding the source)" {
  run "$HOOK" <<< "$(bash_input 'cp -n .env.sample .env')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows writing .env.example" {
  run "$HOOK" <<< "$(bash_input 'printf KEY=\n > .env.example')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows ordinary redirection to a non-secret file" {
  run "$HOOK" <<< "$(bash_input 'git diff > tmp/d.txt')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows stderr redirect to a log that merely starts with .env" {
  run "$HOOK" <<< "$(bash_input 'run.sh 2> .env.log')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp between non-secret files" {
  run "$HOOK" <<< "$(bash_input 'cp src/config.ts dist/config.ts')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Sandbox/config-bypass flags (ported from interior-wildcard deny rules in
# dotclaude/settings.json that prefix_rule syncing can't express)

@test "denies codex exec --dangerously-bypass-approvals-and-sandbox" {
  run "$HOOK" <<< "$(bash_input 'codex exec --dangerously-bypass-approvals-and-sandbox "do stuff"')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies codex exec -s danger-full-access" {
  run "$HOOK" <<< "$(bash_input 'codex exec -s danger-full-access "do stuff"')"
  [[ "$output" == *deny* ]]
}

@test "denies hermes --yolo" {
  run "$HOOK" <<< "$(bash_input 'hermes --yolo run task')"
  [[ "$output" == *deny* ]]
}

@test "denies hermes --ignore-rules mid-command" {
  run "$HOOK" <<< "$(bash_input 'hermes run --ignore-rules task')"
  [[ "$output" == *deny* ]]
}

@test "denies agent-browser close --all" {
  run "$HOOK" <<< "$(bash_input 'agent-browser close --all')"
  [[ "$output" == *deny* ]]
}

@test "allows plain codex exec" {
  run "$HOOK" <<< "$(bash_input 'codex exec "review this diff"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows --all under a different binary (not agent-browser)" {
  run "$HOOK" <<< "$(bash_input 'git add --all')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows bypass flag mentioned only inside quotes" {
  run "$HOOK" <<< "$(bash_input 'rg "danger-full-access" docs/ && echo codex ok')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
