#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/idle-teammates.sh"

setup() {
  export CLAUDE_TEAMS_DIR="$BATS_TEST_TMPDIR/teams"
  mkdir -p "$CLAUDE_TEAMS_DIR/session-abcd1234"
}

make_input() { jq -nc --arg sid "$1" --argjson active "$2" '{session_id:$sid,stop_hook_active:$active}'; }
make_team()  { jq -nc --args '{members: [$ARGS.positional[] | {name: .}]}' "$@" > "$CLAUDE_TEAMS_DIR/session-abcd1234/config.json"; }

@test "blocks with teammate names when members besides team-lead exist" {
  make_team team-lead web-side api-side
  run "$HOOK" <<< "$(make_input "abcd1234-e97c-4d73" false)"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'web-side api-side'* ]]
}

@test "passes silently when only team-lead remains" {
  make_team team-lead
  run "$HOOK" <<< "$(make_input "abcd1234-e97c-4d73" false)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes silently when the session has no team config" {
  run "$HOOK" <<< "$(make_input "ffff0000-none" false)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "loop guard: stop_hook_active bails before any check" {
  make_team team-lead web-side
  run "$HOOK" <<< "$(make_input "abcd1234-e97c-4d73" true)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
