#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/no-pipe-delimiter-alternation.sh"

cmd() { jq -nc --arg c "$1" '{tool_input:{command:$c}}'; }

@test "denies a pipe-delimited sed with an escaped pipe" {
  run "$HOOK" <<< "$(cmd "sed -i '' 's|a\\|b|c|' f.txt")"
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}

@test "denies the perl form" {
  run "$HOOK" <<< "$(cmd "perl -pi -e 's| undefined\\|x||g' main.ts")"
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}

@test "allows a pipe delimiter without an escaped pipe" {
  run "$HOOK" <<< "$(cmd "sed 's|/usr|/opt|' f")"
  [ -z "$output" ]
}

@test "allows a hash delimiter with an escaped pipe" {
  run "$HOOK" <<< "$(cmd "sed 's#a\\|b#c#' f")"
  [ -z "$output" ]
}

@test "ignores commands that are not sed or perl" {
  run "$HOOK" <<< "$(cmd "grep 's|a\\|b' f")"
  [ -z "$output" ]
}
