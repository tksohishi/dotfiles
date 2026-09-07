#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/bg-timeout.sh"

bg_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd, run_in_background: true, description: "d"}}'
}

rewritten() {
  jq -r '.hookSpecificOutput.updatedInput.command' <<< "$output"
}

@test "foreground command untouched" {
  run "$HOOK" <<< "$(jq -n '{tool_input: {command: "sleep 1"}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "background investigation gets 30m cap and quoted command" {
  run "$HOOK" <<< "$(bg_input "http GET 'https://x/y' | jq '.a'")"
  [ "$status" -eq 0 ]
  [ "$(rewritten)" = "timeout -k 10 30m zsh -c 'http GET '\\''https://x/y'\\'' | jq '\\''.a'\\'''" ]
}

@test "dev server shape gets 24h cap" {
  run "$HOOK" <<< "$(bg_input 'bunx wrangler dev --port 1')"
  [[ "$(rewritten)" == "timeout -k 10 24h zsh -c "* ]]
  run "$HOOK" <<< "$(bg_input 'bun scripts/foo.ts --watch')"
  [[ "$(rewritten)" == "timeout -k 10 24h zsh -c "* ]]
  run "$HOOK" <<< "$(bg_input 'bun scripts/runner.ts')"
  [[ "$(rewritten)" == "timeout -k 10 24h zsh -c "* ]]
}

@test "bg-timeout comment overrides, ceiling 24h" {
  run "$HOOK" <<< "$(bg_input 'bun scripts/watch.ts # bg-timeout: 2h')"
  [[ "$(rewritten)" == "timeout -k 10 2h zsh -c "* ]]
  run "$HOOK" <<< "$(bg_input 'sleep 1 # bg-timeout: 3d')"
  [[ "$(rewritten)" == "timeout -k 10 24h zsh -c "* ]]
}

@test "already wrapped in timeout untouched" {
  run "$HOOK" <<< "$(bg_input 'timeout 5 sleep 10')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "other tool_input fields preserved" {
  run "$HOOK" <<< "$(bg_input 'sleep 1')"
  [ "$(jq -r '.hookSpecificOutput.updatedInput.run_in_background' <<< "$output")" = "true" ]
  [ "$(jq -r '.hookSpecificOutput.updatedInput.description' <<< "$output")" = "d" ]
}

@test "expired timeout kills the whole pipeline" {
  run "$HOOK" <<< "$(bg_input 'sleep 30 | cat; echo done')"
  cmd=$(rewritten | sed 's/30m/1s/')
  run zsh -c "$cmd"
  [ "$status" -eq 124 ]
  ! pgrep -f 'sleep 30' >/dev/null
}
