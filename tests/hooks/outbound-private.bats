#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/outbound-private.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  mkdir -p "$HOME/.claude"
  printf '# personal strings\njane.doe@example.com\n(212) 555-0142\n123 Main St\n' > "$HOME/.claude/outbound-private.txt"
}

call() {
  jq -nc --arg tool "$1" --argjson input "$2" '{tool_name: $tool, tool_input: $input}'
}

denied() {
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}

@test "denies WebFetch carrying an email" {
  run "$HOOK" <<< "$(call WebFetch '{"url":"https://example.org/?u=jane.doe@example.com","prompt":"x"}')"
  denied
}

@test "denies WebSearch carrying a phone number in another format" {
  run "$HOOK" <<< "$(call WebSearch '{"query":"who is 212-555-0142"}')"
  denied
}

@test "denies network Bash with a URL-encoded address" {
  run "$HOOK" <<< "$(call Bash '{"command":"http GET https://maps.example.org/route?from=123+Main+St"}')"
  denied
}

@test "allows network Bash without personal strings" {
  run "$HOOK" <<< "$(call Bash '{"command":"http GET https://maps.example.org/route?from=90210"}')"
  [ -z "$output" ]
}

@test "allows local Bash that mentions a personal string" {
  run "$HOOK" <<< "$(call Bash '{"command":"rg jane.doe@example.com notes.md"}')"
  [ -z "$output" ]
}

@test "allows gog with the own account" {
  run "$HOOK" <<< "$(call Bash '{"command":"gog gmail search -a jane.doe@example.com newer_than:1d"}')"
  [ -z "$output" ]
}

@test "denies writing a personal string into a source file" {
  run "$HOOK" <<< "$(call Write '{"file_path":"/p/fetch.ts","content":"headers: { \"User-Agent\": \"bot jane.doe@example.com\" }"}')"
  denied
}

@test "allows writing a personal string into a non-source file" {
  run "$HOOK" <<< "$(call Write '{"file_path":"/p/notes.md","content":"jane.doe@example.com"}')"
  [ -z "$output" ]
}

@test "fails closed on network calls when the list is missing" {
  rm "$HOME/.claude/outbound-private.txt"
  run "$HOOK" <<< "$(call WebFetch '{"url":"https://example.org","prompt":"x"}')"
  denied
  [[ "$output" == *"is missing"* ]]
}

@test "ignores other tools" {
  run "$HOOK" <<< "$(call Read '{"file_path":"/p/a.txt"}')"
  [ -z "$output" ]
}
