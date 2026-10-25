#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/session-trailer.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "allows a commit without a session trailer" {
  run "$HOOK" <<< "$(bash_input 'git commit -m "Add x" -m "- why"')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies a commit with a Claude-Session trailer" {
  run "$HOOK" <<< "$(bash_input 'git commit -m "Add x" -m "Claude-Session: https://claude.ai/code/session_abc"')"
  [[ "$output" == *deny* ]]
}

@test "denies a PR body with a session link" {
  run "$HOOK" <<< "$(bash_input 'gh pr create --title x --body "https://claude.ai/code/session_abc"')"
  [[ "$output" == *deny* ]]
}

@test "ignores a non-commit command that names the trailer" {
  run "$HOOK" <<< "$(bash_input 'rg Claude-Session: notes.md')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
