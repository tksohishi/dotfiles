#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/plan-delegation-nudge.sh"

@test "emits delegation nudge as PostToolUse additionalContext" {
  run "$HOOK" <<< '{"tool_name": "ExitPlanMode", "tool_response": {"plan": "1. do things"}}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("delegate self-contained plan steps")'
}

@test "keeps the small-plan escape hatch in the nudge" {
  run "$HOOK" <<< '{}'
  [[ "$output" == *"stay inline"* ]]
}

@test "exits 0 on empty stdin" {
  run "$HOOK" <<< ''
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}
