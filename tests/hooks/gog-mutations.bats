#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/gog-mutations.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

codex_input() {
  jq -n --arg cmd "$1" '{model: "gpt-5.6", tool_input: {command: $cmd}}'
}

@test "asks on calendar create" {
  run "$HOOK" <<< "$(bash_input 'gog calendar create --summary test')"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"gog calendar create"* ]]
}

@test "asks on alias (new resolves to create)" {
  run "$HOOK" <<< "$(bash_input 'gog calendar new --summary test')"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"gog calendar create"* ]]
}

@test "allows gmail search (read)" {
  run "$HOOK" <<< "$(bash_input 'gog gmail search "meeting notes"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows mutation verb as search argument" {
  run "$HOOK" <<< "$(bash_input 'gog gmail search create')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "asks on nested subcommand (admin groups members add)" {
  run "$HOOK" <<< "$(bash_input 'gog admin groups members add x@example.com')"
  [[ "$output" == *'"ask"'* ]]
}

@test "asks with account flag before subcommand" {
  run "$HOOK" <<< "$(bash_input 'gog -a work gmail send --to x@example.com')"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"gog gmail send"* ]]
}

@test "asks on docs write" {
  run "$HOOK" <<< "$(bash_input 'gog docs write abc123 --text hi')"
  [[ "$output" == *'"ask"'* ]]
}

@test "asks on drive upload" {
  run "$HOOK" <<< "$(bash_input 'gog drive upload ./file.pdf')"
  [[ "$output" == *'"ask"'* ]]
}

@test "asks on api call (arbitrary methods)" {
  run "$HOOK" <<< "$(bash_input 'gog api call gmail.users.messages.delete')"
  [[ "$output" == *'"ask"'* ]]
}

@test "allows gmail get (read)" {
  run "$HOOK" <<< "$(bash_input 'gog gmail get 18c2 --format json')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows non-gog commands without spawning schema" {
  run "$HOOK" <<< "$(bash_input 'git status --short')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows quoted gog bound for another shell" {
  run "$HOOK" <<< "$(bash_input "echo 'gog calendar delete 123'")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies (not asks) under Codex" {
  run "$HOOK" <<< "$(codex_input 'gog calendar delete 123')"
  [[ "$output" == *'"deny"'* ]]
  [[ "$output" != *'"ask"'* ]]
}

@test "asks on gog in pipeline segment" {
  run "$HOOK" <<< "$(bash_input 'cat ids.txt | gog gmail trash 18c2')"
  [[ "$output" == *'"ask"'* ]]
}
