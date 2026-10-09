#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/skill-in-prompt.sh"

setup() {
  cd "$BATS_TEST_TMPDIR"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude/skills/handoff" .agents/skills/host-ops
}

@test "a /skill mid-prompt is routed to the Skill tool" {
  run "$HOOK" <<< '{"prompt":"ではその辺まとめて /handoff"}'
  [ "$status" -eq 0 ]
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" == *'/handoff'* && "$ctx" == *'Skill tool'* ]]
}

@test "a project skill under .agents/skills counts too" {
  run "$HOOK" <<< '{"prompt":"restart it per /host-ops please"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'/host-ops'* ]]
}

@test "a leading slash is a real command and stays silent" {
  run "$HOOK" <<< '{"prompt":"/handoff resume"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a path or an unknown name is not a skill" {
  run "$HOOK" <<< '{"prompt":"read /tmp/foo and /nonesuch"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
