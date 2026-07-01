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
