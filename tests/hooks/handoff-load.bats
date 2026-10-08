#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/handoff-load.sh"

setup() {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p bin
  printf '#!/bin/sh\nrm "$@"\n' > bin/trash
  chmod +x bin/trash
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "passes silently when tmp/handoff.md does not exist" {
  run "$HOOK" <<< '{"source":"clear"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "after /clear loads the handoff into context and trashes the file" {
  mkdir -p tmp
  printf '# Handoff — topic (2026-01-02 13:04)\n\n## Goal\nGet it out.\n\nDetail\n\n## Next step\nShip "it"\n\n## Pointers\n- p\n' > tmp/handoff.md
  touch -t 202601021304 tmp/handoff.md
  run "$HOOK" <<< '{"source":"clear"}'
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' <<< "$output"
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" == *'2026-01-02 13:04'* ]]
  [[ "$ctx" == *'Ship "it"'* ]]
  msg=$(jq -r '.systemMessage' <<< "$output")
  [[ "$msg" == *'Handoff — topic'* ]]
  [[ "$msg" == *'Goal: Get it out.'* ]]
  [[ "$msg" == *'Next step: Ship "it"'* ]]
  [[ "$msg" != *'Detail'* && "$msg" != *'- p'* ]]
  [ ! -e tmp/handoff.md ]
}

@test "a fresh launch loads the handoff too" {
  mkdir -p tmp
  echo "handoff" > tmp/handoff.md
  run "$HOOK" <<< '{"source":"startup"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'handoff'* ]]
  [ ! -e tmp/handoff.md ]
}

@test "resume and compact leave the file alone" {
  mkdir -p tmp
  echo "handoff" > tmp/handoff.md
  for s in resume compact fork; do
    run "$HOOK" <<< "{\"source\":\"$s\"}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ -f tmp/handoff.md ]
}
