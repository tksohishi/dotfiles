#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ls-long.sh"

input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

denied() {
  run "$HOOK" <<< "$(input "$1")"
  [ "$status" -eq 0 ]
  [[ "$output" == *deny* ]]
}

allowed() {
  run "$HOOK" <<< "$(input "$1")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies ls -l and clusters containing l" {
  denied 'ls -l'
  [[ "$output" == *"stat -f"* ]]
  denied 'ls -la tmp/'
  denied 'ls -ltr'
  denied 'ls -A -lh dir'
  denied '/bin/ls -ld x'
  denied 'ls --format=long'
}

@test "denies ls -l in a later segment" {
  denied 'cd tmp && ls -la'
  denied 'D=x; ls -la $D | cut -c25-90'
  denied 'echo a | (ls -l)'
}

@test "allows ls without long format" {
  allowed 'ls'
  allowed 'ls -A tmp'
  allowed 'ls -1t'
  allowed 'ls -- -l'
}

@test "ignores -l on other commands and inside quotes" {
  allowed 'wc -l file'
  allowed 'git log -l'
  allowed 'echo "ls -la"'
  allowed "rg 'ls -l' docs"
  allowed 'tools -l'
}
