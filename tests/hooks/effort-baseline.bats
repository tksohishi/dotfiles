#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/effort-baseline.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  unset CLAUDE_EFFORT
}

@test "records the first effort seen and keeps it" {
  run "$HOOK" <<< '{"session_id":"s1","tool_name":"Bash","effort":{"level":"low"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$TMPDIR/claude-effort-baseline-s1")" = "low" ]
  run "$HOOK" <<< '{"session_id":"s1","tool_name":"Bash","effort":{"level":"high"}}'
  [ "$(cat "$TMPDIR/claude-effort-baseline-s1")" = "low" ]
}

@test "falls back to CLAUDE_EFFORT" {
  CLAUDE_EFFORT=medium run "$HOOK" <<< '{"session_id":"s2","tool_name":"Read"}'
  [ "$(cat "$TMPDIR/claude-effort-baseline-s2")" = "medium" ]
}

@test "writes nothing without an effort or a session id" {
  run "$HOOK" <<< '{"session_id":"s3","tool_name":"Read"}'
  [ ! -e "$TMPDIR/claude-effort-baseline-s3" ]
  run "$HOOK" <<< '{"tool_name":"Read","effort":{"level":"low"}}'
  [ -z "$(ls "$TMPDIR")" ]
}
