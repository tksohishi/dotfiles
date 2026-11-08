#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/webfetch-blocked-domains.sh"

webfetch_input() {
  jq -n --arg url "$1" '{tool_input: {url: $url}}'
}

@test "allows non-blocked domain" {
  run "$HOOK" <<< "$(webfetch_input 'https://example.com/foo')"
  [ "$status" -eq 0 ]
}

@test "denies linkedin.com" {
  run "$HOOK" <<< "$(webfetch_input 'https://linkedin.com/in/foo')"
  [ "$status" -eq 2 ]
}

@test "denies www subdomain of blocked domain" {
  run "$HOOK" <<< "$(webfetch_input 'https://www.linkedin.com/in/foo')"
  [ "$status" -eq 2 ]
}

@test "denies x.com" {
  run "$HOOK" <<< "$(webfetch_input 'https://x.com/elonmusk')"
  [ "$status" -eq 2 ]
}

@test "denies twitter.com" {
  run "$HOOK" <<< "$(webfetch_input 'https://twitter.com/jack')"
  [ "$status" -eq 2 ]
}

@test "denies instagram.com with path" {
  run "$HOOK" <<< "$(webfetch_input 'https://instagram.com/p/abc')"
  [ "$status" -eq 2 ]
}

@test "case-insensitive on host" {
  run "$HOOK" <<< "$(webfetch_input 'https://LinkedIn.com/in/foo')"
  [ "$status" -eq 2 ]
}

@test "local list blocks and can carve an exception out of the public list" {
  dir="$BATS_TEST_TMPDIR/hooks"
  mkdir -p "$dir"
  cp "$HOOK" "$dir/"
  printf 'linkedin.com|public block\n' > "$dir/webfetch-blocked-domains.txt"
  printf '!www.linkedin.com\nexample.org|local block\n' > "$dir/webfetch-blocked-domains.local.txt"
  run "$dir/webfetch-blocked-domains.sh" <<< "$(webfetch_input 'https://example.org/a')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"local block"* ]]
  run "$dir/webfetch-blocked-domains.sh" <<< "$(webfetch_input 'https://www.linkedin.com/in/foo')"
  [ "$status" -eq 0 ]
  run "$dir/webfetch-blocked-domains.sh" <<< "$(webfetch_input 'https://linkedin.com/in/foo')"
  [ "$status" -eq 2 ]
}

@test "works without a local list" {
  dir="$BATS_TEST_TMPDIR/hooks"
  mkdir -p "$dir"
  cp "$HOOK" "$dir/"
  printf 'linkedin.com|public block\n' > "$dir/webfetch-blocked-domains.txt"
  run "$dir/webfetch-blocked-domains.sh" <<< "$(webfetch_input 'https://linkedin.com/in/foo')"
  [ "$status" -eq 2 ]
  run "$dir/webfetch-blocked-domains.sh" <<< "$(webfetch_input 'https://example.com/')"
  [ "$status" -eq 0 ]
}

@test "aws.amazon.com is not caught by the amazon.com shop rule" {
  run "$HOOK" <<< "$(webfetch_input 'https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/')"
  [ "$status" -eq 0 ]
}

@test "www.amazon.com is still denied" {
  run "$HOOK" <<< "$(webfetch_input 'https://www.amazon.com/dp/B000')"
  [ "$status" -eq 2 ]
}

@test "a deny records the host as a failed WebFetch rung for the ladder gate" {
  export HOME="$BATS_TEST_TMPDIR"
  run "$HOOK" <<< "$(jq -n '{session_id: "s1", tool_input: {url: "https://www.cooking.nytimes.com/r"}}')"
  [ "$status" -eq 2 ]
  [ "$(cat "$BATS_TEST_TMPDIR/.cache/fetch-blocked/s1.tsv")" = "$(printf 'cooking.nytimes.com\tblocked\tWebFetch')" ]
}

@test "an allowed fetch writes no state" {
  export HOME="$BATS_TEST_TMPDIR"
  run "$HOOK" <<< "$(jq -n '{session_id: "s1", tool_input: {url: "https://example.com/"}}')"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/.cache/fetch-blocked/s1.tsv" ]
}

@test "a deny that routes to another tool is not recorded" {
  export HOME="$BATS_TEST_TMPDIR"
  run "$HOOK" <<< "$(jq -n '{session_id: "s1", tool_input: {url: "https://t.me/somechannel"}}')"
  [ "$status" -eq 2 ]
  [ ! -e "$BATS_TEST_TMPDIR/.cache/fetch-blocked/s1.tsv" ]
}

@test "deny then a passing httpie retry clears the Stop gate, whatever the host's case or userinfo" {
  export HOME="$BATS_TEST_TMPDIR"
  DIR="$BATS_TEST_DIRNAME/../../dotagents/hooks"
  run "$HOOK" <<< "$(jq -n '{session_id: "s2", tool_input: {url: "https://WWW.Audit.NYTimes.com/x"}}')"
  [ "$status" -eq 2 ]
  run "$DIR/fetch-ladder-gate.sh" <<< '{"session_id":"s2","hook_event_name":"Stop"}'
  [[ "$output" == *'audit.nytimes.com'* ]]
  jq -n '{session_id:"s2", tool_name:"Bash", tool_input:{command:"http GET https://reader@www.AUDIT.nytimes.com/x --ignore-stdin"}, tool_response:"<html><title>Audit</title>ok</html>"}' | "$DIR/fetch-blocked-detect.sh" >/dev/null
  rm -f "$BATS_TEST_TMPDIR/.cache/fetch-blocked/s2.gate"
  run "$DIR/fetch-ladder-gate.sh" <<< '{"session_id":"s2","hook_event_name":"Stop"}'
  [ -z "$output" ]
}
