#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/bash-antipatterns.sh"

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

@test "denies cp -r without -n" {
  run "$HOOK" <<< "$(bash_input 'cp -r src dst')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"cp -an"* ]]
}

@test "denies cp -R without -n" {
  run "$HOOK" <<< "$(bash_input 'cp -R src dst')"
  [[ "$output" == *deny* ]]
}

@test "denies cp -a without -n" {
  run "$HOOK" <<< "$(bash_input 'cp -a src dst')"
  [[ "$output" == *deny* ]]
}

@test "denies cp -rf without -n" {
  run "$HOOK" <<< "$(bash_input 'cp -rf src dst')"
  [[ "$output" == *deny* ]]
}

@test "allows cp -an" {
  run "$HOOK" <<< "$(bash_input 'cp -an src/ dst/')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp -na" {
  run "$HOOK" <<< "$(bash_input 'cp -na src/ dst/')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp -rn" {
  run "$HOOK" <<< "$(bash_input 'cp -rn src/ dst/')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp without recursive flag" {
  run "$HOOK" <<< "$(bash_input 'cp foo bar')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cp -n single file" {
  run "$HOOK" <<< "$(bash_input 'cp -n foo bar')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
