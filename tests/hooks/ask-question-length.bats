#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ask-question-length.sh"

long() { printf 'あ%.0s' $(seq "$1"); }

payload() {
  jq -nc --arg q "$1" --arg d "$2" --arg p "${3:-}" '{
    tool_name: "AskUserQuestion",
    tool_input: {questions: [{question: $q, header: "Approach", multiSelect: false,
      options: [{label: "A", description: $d, preview: $p}, {label: "B", description: "short"}]}]}
  }'
}

@test "short question and options pass silently" {
  run "$HOOK" <<< "$(payload "Which approach?" "Faster, less flexible")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a long question is denied and named" {
  run "$HOOK" <<< "$(payload "$(long 101)" "short")"
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
  [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$output")" == *'question "Approach"'* ]]
}

@test "a long option description is denied and named" {
  run "$HOOK" <<< "$(payload "Which?" "$(long 101)")"
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
  [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$output")" == *'option "A"'* ]]
}

@test "exactly 100 characters passes" {
  run "$HOOK" <<< "$(payload "$(long 100)" "$(long 100)")"
  [ -z "$output" ]
}

@test "a long preview is allowed" {
  run "$HOOK" <<< "$(payload "Which layout?" "short" "$(long 2000)")"
  [ -z "$output" ]
}
