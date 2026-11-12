#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ja-spacing.ts"

setup() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : > "$T"
}

user() { jq -nc --arg s "$1" '{type:"user",message:{role:"user",content:$s}}' >> "$T"; }
claude() { jq -nc --arg s "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$s}]}}' >> "$T"; }
run_hook() { run bun "$HOOK" <<< "$(jq -nc --arg t "$T" '{hook_event_name:"UserPromptSubmit",transcript_path:$t}')"; }

@test "notes a space between a number and Japanese, to the agent only" {
  user "どう？"
  claude "合計は 3 件です。"
  run_hook
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' <<< "$output"
  jq -e '.hookSpecificOutput.additionalContext | test("ja-spacing")' <<< "$output"
  jq -e 'has("systemMessage") | not' <<< "$output"
}

@test "notes a missing space after 。 mid-line" {
  user "どう？"
  claude "完了しました。次に進みます。"
  run_hook
  jq -e '.hookSpecificOutput.additionalContext | test("。 の直後")' <<< "$output"
}

@test "passes a clean reply" {
  user "どう？"
  claude "合計は3件です。 Latin word の前後は空白でよい。"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skips code spans, fences and table rows" {
  user "どう？"
  claude $'`a 3` を使う\n\n```\n値 3 件\n```\n\n| 列 | 3 件 |'
  run_hook
  [ -z "$output" ]
}

@test "counts the streak across replies" {
  user "a"
  claude "合計 3 件"
  user "b"
  claude "残り 2 件"
  run_hook
  jq -e '.hookSpecificOutput.additionalContext | test("2返答連続")' <<< "$output"
}
