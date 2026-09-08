#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/session-title.sh"

@test "names the session after the cwd basename on startup" {
  run "$HOOK" <<< '{"source":"startup","cwd":"/Users/x/life"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.sessionTitle' <<< "$output")" = "life" ]
  jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' <<< "$output"
}

@test "strips a leading dot (.dotfiles -> dotfiles)" {
  run "$HOOK" <<< '{"source":"resume","cwd":"/Users/x/.dotfiles"}'
  [ "$(jq -r '.hookSpecificOutput.sessionTitle' <<< "$output")" = "dotfiles" ]
}

@test "keeps a title the user already set" {
  run "$HOOK" <<< '{"source":"startup","cwd":"/Users/x/life","session_title":"my-work"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does nothing on clear and compact" {
  run "$HOOK" <<< '{"source":"clear","cwd":"/Users/x/life"}'
  [ -z "$output" ]
  run "$HOOK" <<< '{"source":"compact","cwd":"/Users/x/life"}'
  [ -z "$output" ]
}
