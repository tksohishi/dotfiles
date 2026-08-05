#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/plan-delegation-annotations.sh"

payload() {
  jq -nc --arg plan "$1" '{tool_name: "ExitPlanMode", tool_input: {plan: $plan}}'
}

@test "small plan (under 3 files) passes without annotations" {
  run "$HOOK" <<< "$(payload '1. Edit src/App.tsx to add the modal. 2. Update src/style.css.')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "large plan without annotations is denied with guidance" {
  run "$HOOK" <<< "$(payload '1. Edit apps/api/src/index.ts. 2. Edit apps/web/src/App.tsx. 3. Update packages/ui/src/WeeklyReview.tsx. 4. Adjust apps/web/src/style.css.')"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | test("\\[subagent\\] or \\[inline\\]")'
}

@test "large plan with [subagent] annotations passes" {
  run "$HOOK" <<< "$(payload '1. [subagent] Edit apps/api/src/index.ts. 2. [inline] Edit apps/web/src/App.tsx (coupled to 1). 3. [subagent] packages/ui/src/WeeklyReview.tsx. 4. apps/web/src/style.css.')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "large plan with Delegation: none opt-out passes" {
  run "$HOOK" <<< "$(payload 'Delegation: none — tightly coupled refactor.
1. Edit apps/api/src/index.ts. 2. apps/web/src/App.tsx. 3. packages/ui/src/WeeklyReview.tsx.')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "file count dedupes repeated mentions of the same file" {
  run "$HOOK" <<< "$(payload 'Edit src/App.tsx, then test src/App.tsx, then verify src/App.tsx and src/api.ts.')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty or missing plan passes" {
  run "$HOOK" <<< '{"tool_name": "ExitPlanMode", "tool_input": {}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
