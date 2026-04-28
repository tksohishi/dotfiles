#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/agent-browser-context.sh"

setup() {
  TMPCWD=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPCWD"
}

@test "ignores non-agent-browser command" {
  input=$(jq -n '{tool_input: {command: "ls"}}')
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ignores agent-browser --help" {
  input=$(jq -n '{tool_input: {command: "agent-browser --help"}}')
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ignores agent-browser -h" {
  input=$(jq -n '{tool_input: {command: "agent-browser -h"}}')
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "warns about missing agent-browser.json when cwd lacks it" {
  input=$(jq -n --arg cwd "$TMPCWD" '{tool_input: {command: "agent-browser open https://example.com"}, cwd: $cwd}')
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-browser-init"* ]]
  [[ "$output" == *"--help"* ]]
}

@test "shows only --help reminder when agent-browser.json exists" {
  touch "$TMPCWD/agent-browser.json"
  input=$(jq -n --arg cwd "$TMPCWD" '{tool_input: {command: "agent-browser open https://example.com"}, cwd: $cwd}')
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [[ "$output" != *"agent-browser-init"* ]]
  [[ "$output" == *"--help"* ]]
}
