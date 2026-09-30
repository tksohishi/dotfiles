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
