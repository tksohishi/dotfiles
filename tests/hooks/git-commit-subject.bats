#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/git-commit-subject.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "ignores non-git-commit command" {
  run "$HOOK" <<< "$(bash_input 'git status')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows short subject" {
  run "$HOOK" <<< "$(bash_input 'git commit -m "Add bats tests"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies subject over 80 chars without body" {
  long=$(printf 'a%.0s' {1..90})
  cmd="git commit -m \"$long\""
  run "$HOOK" <<< "$(bash_input "$cmd")"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"blank line after the subject"* ]]
}

@test "denies subject over 80 chars with body" {
  long=$(printf 'a%.0s' {1..90})
  nl=$'\n'
  msg="${long}${nl}${nl}body bullets"
  cmd="git commit -m \"$msg\""
  run "$HOOK" <<< "$(bash_input "$cmd")"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"Shorten the subject"* ]]
}
