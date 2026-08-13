#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/bash-output-efficiency.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

# --- curl ---

@test "denies curl download" {
  run "$HOOK" <<< "$(bash_input 'curl -s -o out.png https://example.com/img.png')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"http --download"* ]]
}

@test "denies plain curl fetch" {
  run "$HOOK" <<< "$(bash_input 'curl -s https://example.com/api')"
  [[ "$output" == *deny* ]]
}

@test "denies curl as pipeline segment" {
  run "$HOOK" <<< "$(bash_input 'cat body.json | curl -T - https://example.com')"
  [[ "$output" == *deny* ]]
}

@test "allows curl --version" {
  run "$HOOK" <<< "$(bash_input 'curl --version')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows curl --help" {
  run "$HOOK" <<< "$(bash_input 'curl --help')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows quoted curl bound for a remote shell" {
  run "$HOOK" <<< "$(bash_input "ssh host 'curl -s https://internal/health'")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows httpie" {
  run "$HOOK" <<< "$(bash_input 'http GET https://example.com')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows curlie-like names (no false prefix match)" {
  run "$HOOK" <<< "$(bash_input 'curlie GET https://example.com')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- git status ---

@test "denies bare git status" {
  run "$HOOK" <<< "$(bash_input 'git status')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"--short"* ]]
}

@test "allows git status --short" {
  run "$HOOK" <<< "$(bash_input 'git status --short')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git status -sb" {
  run "$HOOK" <<< "$(bash_input 'git status -sb')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git status --porcelain=v2" {
  run "$HOOK" <<< "$(bash_input 'git status --porcelain=v2')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies git -C repo status without short flag" {
  run "$HOOK" <<< "$(bash_input 'git -C tmp/clone status')"
  [[ "$output" == *deny* ]]
}

@test "allows git -C repo status --short" {
  run "$HOOK" <<< "$(bash_input 'git -C tmp/clone status --short')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- git log ---

@test "denies bare git log" {
  run "$HOOK" <<< "$(bash_input 'git log')"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"--oneline"* ]]
}

@test "allows git log --oneline" {
  run "$HOOK" <<< "$(bash_input 'git log --oneline')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git log -1 (full message of one commit)" {
  run "$HOOK" <<< "$(bash_input 'git log -1')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git log -n 5" {
  run "$HOOK" <<< "$(bash_input 'git log -n 5 --stat')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git log --format" {
  run "$HOOK" <<< "$(bash_input 'git log --format=%H%s main..HEAD')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows unbounded git log piped into head" {
  run "$HOOK" <<< "$(bash_input 'git log --stat | head -40')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies git log in a command chain without bound" {
  run "$HOOK" <<< "$(bash_input 'cd tmp/clone && git log')"
  [[ "$output" == *deny* ]]
}

# --- untouched shapes ---

@test "allows git diff (deliberately uncovered)" {
  run "$HOOK" <<< "$(bash_input 'git diff')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git commit referencing status in message" {
  run "$HOOK" <<< "$(bash_input 'git commit -m "Show status in sidebar"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows unrelated commands" {
  run "$HOOK" <<< "$(bash_input 'rg -n pattern src/ | head -20')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
