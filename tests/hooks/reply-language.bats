#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/reply-language.ts"

setup() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : > "$T"
}

user() { jq -nc --arg s "$1" '{type:"user",message:{role:"user",content:$s}}' >> "$T"; }
stop() { run bun "$HOOK" <<< "$(jq -nc --arg t "$T" --arg m "$1" '{hook_event_name:"Stop",transcript_path:$t,last_assistant_message:$m,stop_hook_active:false}')"; }

@test "blocks an English reply to a Japanese prompt" {
  user "これ直して"
  stop "I fixed the bug in the parser and pushed the commit to main."
  [ "$status" -eq 0 ]
  jq -e '.decision == "block"' <<< "$output"
}

@test "passes a Japanese reply" {
  user "これ直して"
  stop "パーサーのバグを直して main に push しました。"
  [ -z "$output" ]
}

@test "passes an English reply to an English prompt" {
  user "please fix the parser bug"
  stop "I fixed the bug in the parser and pushed the commit to main."
  [ -z "$output" ]
}

@test "does not count a blockquoted draft for an outside party" {
  user "返信の下書きを書いて"
  stop $'下書きです。\n\n> Thanks for the update, I will review the proposal and get back to you tomorrow.'
  [ -z "$output" ]
}

@test "does not block twice in a row" {
  user "これ直して"
  run bun "$HOOK" <<< "$(jq -nc --arg t "$T" '{hook_event_name:"Stop",transcript_path:$t,last_assistant_message:"I fixed the bug in the parser and pushed it.",stop_hook_active:true}')"
  [ -z "$output" ]
}
