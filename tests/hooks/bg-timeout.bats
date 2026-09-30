#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/bg-timeout.sh"

bg_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd, run_in_background: true, description: "d"}}'
}

timeout_ms() {
  jq -r '.hookSpecificOutput.updatedInput.timeout' <<< "$output"
}

@test "foreground command untouched" {
  run "$HOOK" <<< "$(jq -n '{tool_input: {command: "sleep 1"}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "plain background command keeps Claude's default" {
  run "$HOOK" <<< "$(bg_input "http GET 'https://x/y' | jq '.a'")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "dev server shape gets the 2h maximum" {
  run "$HOOK" <<< "$(bg_input 'bunx wrangler dev --port 1')"
  [ "$(timeout_ms)" = "7200000" ]
  run "$HOOK" <<< "$(bg_input 'bun scripts/foo.ts --watch')"
  [ "$(timeout_ms)" = "7200000" ]
  run "$HOOK" <<< "$(bg_input 'bun scripts/runner.ts')"
  [ "$(timeout_ms)" = "7200000" ]
}

@test "bg-timeout comment sets the cap, clamped to 2h" {
  run "$HOOK" <<< "$(bg_input 'bun scripts/watch.ts # bg-timeout: 90m')"
  [ "$(timeout_ms)" = "5400000" ]
  run "$HOOK" <<< "$(bg_input 'sleep 1 # bg-timeout: 3d')"
  [ "$(timeout_ms)" = "7200000" ]
}

@test "explicit timeout kept unless a comment overrides it" {
  run "$HOOK" <<< "$(jq -n '{tool_input: {command: "bunx vite dev", run_in_background: true, timeout: 60000}}')"
  [ -z "$output" ]
  run "$HOOK" <<< "$(jq -n '{tool_input: {command: "sleep 1 # bg-timeout: 10m", run_in_background: true, timeout: 60000}}')"
  [ "$(timeout_ms)" = "600000" ]
}

@test "other tool_input fields preserved" {
  run "$HOOK" <<< "$(bg_input 'bunx vite dev')"
  [ "$(jq -r '.hookSpecificOutput.updatedInput.command' <<< "$output")" = "bunx vite dev" ]
  [ "$(jq -r '.hookSpecificOutput.updatedInput.run_in_background' <<< "$output")" = "true" ]
  [ "$(jq -r '.hookSpecificOutput.updatedInput.description' <<< "$output")" = "d" ]
}
