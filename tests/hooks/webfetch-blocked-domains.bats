#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/webfetch-blocked-domains.sh"

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
