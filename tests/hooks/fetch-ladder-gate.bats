#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/fetch-ladder-gate.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.cache/fetch-blocked" "$HOME/.claude/skills/fetch-blocked/references"
  printf '| iherb.com | n/a | headed works |\n' > "$HOME/.claude/skills/fetch-blocked/references/sites.md"
  STATE="$HOME/.cache/fetch-blocked/sess1.tsv"
}

stop_input() {
  jq -n '{session_id: "sess1", hook_event_name: "Stop"}'
}

assert_blocks() {
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no state file stays silent" {
  run "$HOOK" <<< "$(stop_input)"
  assert_silent
}

@test "missing session_id stays silent" {
  printf 'tools.usps.com\tblocked\thttpie\n' > "$STATE"
  run "$HOOK" <<< '{}'
  assert_silent
}

@test "blocked host with rungs left blocks the stop and names the host" {
  printf 'tools.usps.com\tblocked\thttpie\n' > "$STATE"
  run "$HOOK" <<< "$(stop_input)"
  assert_blocks
  echo "$output" | jq -e '.reason | test("tools.usps.com") and test("httpie")' >/dev/null
}

@test "host that later passed stays silent" {
  printf 'tools.usps.com\tblocked\thttpie\ntools.usps.com\tpassed\tagent-browser headed\n' > "$STATE"
  run "$HOOK" <<< "$(stop_input)"
  assert_silent
}

@test "host that failed the last rung stays silent" {
  printf 'example.com\tblocked\thttpie\nexample.com\tblocked\tpatchright-fetch headed\n' > "$STATE"
  run "$HOOK" <<< "$(stop_input)"
  assert_silent
}

@test "host recorded in sites.md stays silent" {
  printf 'iherb.com\tblocked\thttpie\n' > "$STATE"
  run "$HOOK" <<< "$(stop_input)"
  assert_silent
}

@test "blocks at most twice per session" {
  printf 'tools.usps.com\tblocked\thttpie\n' > "$STATE"
  run "$HOOK" <<< "$(stop_input)"
  assert_blocks
  run "$HOOK" <<< "$(stop_input)"
  assert_blocks
  run "$HOOK" <<< "$(stop_input)"
  assert_silent
}
