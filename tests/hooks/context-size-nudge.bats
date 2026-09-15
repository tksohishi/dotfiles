#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/context-size-nudge.sh"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : > "$T"
}

# append an assistant message whose context totals $1 tokens
turn() {
  printf '{"type":"user","message":{"content":"hi"}}\n' >> "$T"
  printf '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":%d,"cache_creation_input_tokens":0}}}\n' "$(($1 - 10))" >> "$T"
}

prompt() {
  run "$HOOK" <<< "{\"session_id\":\"$1\",\"transcript_path\":\"$T\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"x\"}"
}

@test "silent under 300K" {
  turn 250000
  prompt s1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fires at 300K with a user message and agent context naming handoff and keepalive" {
  turn 312000
  prompt s2
  jq -e '.systemMessage | test("312K")' <<< "$output"
  jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' <<< "$output"
  jq -e '.hookSpecificOutput.additionalContext | test("/handoff") and test("/keepalive")' <<< "$output"
}

@test "fires once per 100K band" {
  turn 310000
  prompt s3
  [ -n "$output" ]
  turn 390000
  prompt s3
  [ -z "$output" ]
  turn 405000
  prompt s3
  jq -e '.systemMessage | test("405K")' <<< "$output"
}

@test "re-arms after the context shrinks" {
  turn 350000
  prompt s4
  [ -n "$output" ]
  turn 80000
  prompt s4
  [ -z "$output" ]
  turn 320000
  prompt s4
  [ -n "$output" ]
}

@test "reads the latest assistant usage, not an earlier larger one" {
  turn 500000
  turn 120000
  prompt s5
  [ -z "$output" ]
}

@test "silent when the transcript is missing" {
  run "$HOOK" <<< '{"session_id":"s6","transcript_path":"/nonexistent.jsonl"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
