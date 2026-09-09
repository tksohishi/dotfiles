#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/plan-exit-effort-gate.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  unset CLAUDE_EFFORT
}

@test "denies when effort differs from the recorded baseline" {
  printf low > "$TMPDIR/claude-effort-baseline-s1"
  run "$HOOK" <<< '{"session_id":"s1","effort":{"level":"high"}}'
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
  jq -e '.hookSpecificOutput.permissionDecisionReason | test("/effort low")' <<< "$output"
}

@test "allows when effort matches the baseline" {
  printf low > "$TMPDIR/claude-effort-baseline-s2"
  run "$HOOK" <<< '{"session_id":"s2","effort":{"level":"low"}}'
  [ -z "$output" ]
}

@test "allows when no baseline was recorded" {
  run "$HOOK" <<< '{"session_id":"s3","effort":{"level":"high"}}'
  [ -z "$output" ]
}

@test "falls back to CLAUDE_EFFORT" {
  printf low > "$TMPDIR/claude-effort-baseline-s4"
  CLAUDE_EFFORT=medium run "$HOOK" <<< '{"session_id":"s4"}'
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}

@test "denies once, then lets the retry through" {
  printf low > "$TMPDIR/claude-effort-baseline-s5"
  run "$HOOK" <<< '{"session_id":"s5","effort":{"level":"high"}}'
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
  run "$HOOK" <<< '{"session_id":"s5","effort":{"level":"high"}}'
  [ -z "$output" ]
  run "$HOOK" <<< '{"session_id":"s5","effort":{"level":"high"}}'
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}
