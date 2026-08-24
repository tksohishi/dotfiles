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

@test "allows gmail draft create (exempt: draft composition)" {
  run "$HOOK" <<< "$(bash_input 'gog gmail draft create --to x@example.com --subject hi')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows gmail drafts reply via alias" {
  run "$HOOK" <<< "$(bash_input 'gog mail drafts reply 18c2 --body ok')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "asks on gmail drafts send (not exempt)" {
  run "$HOOK" <<< "$(bash_input 'gog gmail drafts send 18c2')"
  [[ "$output" == *'"ask"'* ]]
}

@test "allows gmail drafts delete (exempt: only discards unsent text)" {
  run "$HOOK" <<< "$(bash_input 'gog gmail draft delete 18c2')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows --help on mutation subcommand" {
  run "$HOOK" <<< "$(bash_input 'gog gmail send --help')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows -h on mutation subcommand" {
  run "$HOOK" <<< "$(bash_input 'gog calendar create -h')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "asks on gog in pipeline segment" {
  run "$HOOK" <<< "$(bash_input 'cat ids.txt | gog gmail trash 18c2')"
  [[ "$output" == *'"ask"'* ]]
}
