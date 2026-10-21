#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/cron-state.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  DIR="$HOME/.claude/state/crons/s1"
}

create() {
  "$HOOK" <<< "{\"session_id\":\"s1\",\"tool_name\":\"CronCreate\",\"tool_input\":{\"cron\":\"$1\",\"prompt\":\"x\"$2},\"tool_response\":{\"id\":\"j1\",\"humanSchedule\":\"Every 30 minutes\",\"recurring\":true,\"nextFireAt\":$3}}"
}

fields() { cut -d' ' -f"$1" "$DIR/j1"; }

@test "13,43 records minutes and the scheduler offset" {
  run create "13,43 * * * *" "" 1792545499302.25
  [ "$status" -eq 0 ]
  [ "$(fields 1)" = 1792545499 ]
  [ "$(fields 2)" = true ]
  [ "$(fields 4)" = 319 ]
  [ "$(fields 5-)" = "13 43" ]
}

@test "*/30 expands from tool_input.cron, not humanSchedule" {
  run create "*/30 * * * *" "" 1792272771000
  [ "$status" -eq 0 ]
  [ "$(fields 4)" = 171 ]
  [ "$(fields 5-)" = "0 30" ]
}

@test "range with step expands" {
  run create "5-25/10 * * * *" "" 1792272771000
  [ "$(fields 5-)" = "5 15 25" ]
}

@test "non-hourly pattern keeps no minutes" {
  run create "7 */2 * * *" "" 1792272771000
  [ "$(fields 4)" = 0 ]
  [ -z "$(fields 5-)" ]
}

@test "one-shot keeps no minutes" {
  run create "17 9 25 12 *" ",\"recurring\":false" 1798208220000
  [ "$(fields 2)" = false ]
  [ -z "$(fields 5-)" ]
}

@test "CronDelete removes the job" {
  create "13,43 * * * *" "" 1792545499302
  [ -f "$DIR/j1" ]
  run "$HOOK" <<< '{"session_id":"s1","tool_name":"CronDelete","tool_input":{"id":"j1"}}'
  [ "$status" -eq 0 ]
  [ ! -f "$DIR/j1" ]
}

@test "no session id writes nothing" {
  run "$HOOK" <<< '{"tool_name":"CronCreate","tool_input":{"cron":"* * * * *"},"tool_response":{"id":"j1","nextFireAt":1}}'
  [ "$status" -eq 0 ]
  [ ! -d "$HOME/.claude/state/crons" ]
}
