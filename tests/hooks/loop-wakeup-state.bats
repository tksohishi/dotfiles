#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/loop-wakeup-state.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  STATE="$HOME/.claude/state/wakeups/s1"
}

@test "records now + delaySeconds for the session" {
  before=$(date +%s)
  run "$HOOK" <<< '{"session_id":"s1","tool_input":{"delaySeconds":3000,"prompt":"x"}}'
  [ "$status" -eq 0 ]
  t=$(cat "$STATE")
  [ "$t" -ge $((before + 3000)) ]
  [ "$t" -le $(($(date +%s) + 3000)) ]
}

@test "stop removes the record" {
  "$HOOK" <<< '{"session_id":"s1","tool_input":{"delaySeconds":60}}'
  [ -f "$STATE" ]
  run "$HOOK" <<< '{"session_id":"s1","tool_input":{"stop":true}}'
  [ "$status" -eq 0 ]
  [ ! -f "$STATE" ]
}

@test "fractional delay is truncated" {
  run "$HOOK" <<< '{"session_id":"s1","tool_input":{"delaySeconds":90.5}}'
  [ "$status" -eq 0 ]
  [ -f "$STATE" ]
}

@test "no session id writes nothing" {
  run "$HOOK" <<< '{"tool_input":{"delaySeconds":60}}'
  [ "$status" -eq 0 ]
  [ ! -d "$HOME/.claude/state/wakeups" ]
}
