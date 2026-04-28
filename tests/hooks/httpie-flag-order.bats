#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/httpie-flag-order.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "allows http METHOD URL form" {
  run "$HOOK" <<< "$(bash_input 'http GET https://example.com')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows https METHOD URL form" {
  run "$HOOK" <<< "$(bash_input 'https POST https://example.com')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies http -flag URL" {
  run "$HOOK" <<< "$(bash_input 'http -j https://example.com')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"Canonical form"* ]]
}

@test "allows http --help" {
  run "$HOOK" <<< "$(bash_input 'http --help')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows http --version" {
  run "$HOOK" <<< "$(bash_input 'http --version')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows http inside pipeline (not first token)" {
  run "$HOOK" <<< "$(bash_input 'curl -s url | http POST https://x')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
