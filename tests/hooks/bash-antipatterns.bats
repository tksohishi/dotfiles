#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/bash-antipatterns.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "denies cd-chain" {
  run "$HOOK" <<< "$(bash_input 'cd /tmp && ls')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"cd <dir> && <cmd>"* ]]
}

@test "denies for loop" {
  run "$HOOK" <<< "$(bash_input 'for x in a b c; do echo $x; done')"
  [[ "$output" == *deny* ]]
}

@test "denies while loop" {
  run "$HOOK" <<< "$(bash_input 'while true; do echo hi; done')"
  [[ "$output" == *deny* ]]
}

@test "allows until polling loop" {
  run "$HOOK" <<< "$(bash_input 'until test -f /tmp/x; do sleep 1; done')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies bare head <file>" {
  run "$HOOK" <<< "$(bash_input 'head /tmp/x')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"Read tool"* ]]
}

@test "allows piped head" {
  run "$HOOK" <<< "$(bash_input 'cat /tmp/x | head -5')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies sed -n range" {
  run "$HOOK" <<< "$(bash_input 'sed -n 1,5p /tmp/x')"
  [[ "$output" == *deny* ]]
}

@test "allows piped sed -n" {
  run "$HOOK" <<< "$(bash_input 'cat /tmp/x | sed -n 5p')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies \$? exit-status reference" {
  run "$HOOK" <<< "$(bash_input 'echo $?')"
  [[ "$output" == *deny* ]]
}

@test "allows benign command" {
  run "$HOOK" <<< "$(bash_input 'git status')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
