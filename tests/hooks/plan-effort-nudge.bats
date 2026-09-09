#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/plan-effort-nudge.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  unset CLAUDE_EFFORT
}

@test "nudges in plan mode at low effort" {
  run "$HOOK" <<< '{"permission_mode":"plan","effort":{"level":"low"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  jq -e '.systemMessage | test("higher effort")' <<< "$output"
}

@test "falls back to CLAUDE_EFFORT when the input has no effort field" {
  CLAUDE_EFFORT=low run "$HOOK" <<< '{"permission_mode":"plan","session_id":"s2"}'
  jq -e '.systemMessage' <<< "$output"
}

@test "silent outside plan mode" {
  CLAUDE_EFFORT=low run "$HOOK" <<< '{"permission_mode":"auto","session_id":"s3"}'
  [ -z "$output" ]
}

@test "silent when effort is already above low" {
  run "$HOOK" <<< '{"permission_mode":"plan","effort":{"level":"medium"},"session_id":"s4"}'
  [ -z "$output" ]
}

@test "fires once per session" {
  run "$HOOK" <<< '{"permission_mode":"plan","effort":{"level":"low"},"session_id":"s5"}'
  [ -n "$output" ]
  run "$HOOK" <<< '{"permission_mode":"plan","effort":{"level":"low"},"session_id":"s5"}'
  [ -z "$output" ]
}

@test "falls back to the recorded session baseline" {
  printf low > "$TMPDIR/claude-effort-baseline-s6"
  run "$HOOK" <<< '{"permission_mode":"plan","session_id":"s6"}'
  jq -e '.systemMessage' <<< "$output"
}

@test "silent when no effort source exists" {
  run "$HOOK" <<< '{"permission_mode":"plan","session_id":"s7"}'
  [ -z "$output" ]
}
