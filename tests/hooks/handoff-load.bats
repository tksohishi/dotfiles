#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/handoff-stale.sh"

setup() {
  cd "$BATS_TEST_TMPDIR"
}

@test "passes silently when tmp/handoff.md does not exist" {
  run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "emits valid SessionStart JSON when tmp/handoff.md exists" {
  mkdir -p tmp
  echo "stale handoff" > tmp/handoff.md
  run "$HOOK"
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' <<< "$output"
  [[ "$output" == *'/handoff resume'* ]]
}

@test "context names the file mtime" {
  mkdir -p tmp
  touch -t 202601021304 tmp/handoff.md
  run "$HOOK"
  [ "$status" -eq 0 ]
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" == *'2026-01-02 13:04'* ]]
}
