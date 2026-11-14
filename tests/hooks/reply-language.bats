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

@test "passes English when the Japanese prompt asks for English" {
  user "空の色について一言。ただし返答は必ず英語の1文だけで書いて。"
  stop "The sky is a clear and brilliant blue this afternoon."
  [ -z "$output" ]
  user "この文を英訳して: 今日は晴れ"
  stop "It is sunny today, with clear skies all around the city."
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

claude() { jq -nc --arg s "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$s}]}}' >> "$T"; }
result() { jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:"x",content:"ok"}]}}' >> "$T"; }
# a headless run has written the call's own tool_use by PreToolUse; an interactive session has not (no `landed`)
landed() { jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_q",name:"AskUserQuestion",input:{}}]}}' >> "$T"; }
ask() { run bun "$HOOK" <<< "$(jq -nc --arg t "$T" --arg q "$1" '{hook_event_name:"PreToolUse",tool_name:"AskUserQuestion",tool_use_id:"toolu_q",transcript_path:$t,tool_input:{questions:[{question:$q}]}}')"; }
EXPLAIN="degen-para からの依頼です。 質問ダイアログの直前に英語の説明が出ることがありました。 今の hook は最後の返答しか見ていません。 決めてもらうのは、質問の前にも言語判定を走らせるかどうかです。"

@test "passes a short question after a Japanese explanation" {
  user "どうする？"
  claude "$EXPLAIN"
  landed
  ask "質問の前にも言語判定を走らせる?"
  [ -z "$output" ]
}

@test "denies a question with no explanation since the last tool result" {
  user "どうする？"
  claude "$EXPLAIN"
  result
  landed
  ask "質問の前にも言語判定を走らせる?"
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
  jq -e '.hookSpecificOutput.permissionDecisionReason | test("説明がない")' <<< "$output"
}

@test "denies a question after an English explanation" {
  user "どうする？"
  claude "The reply-language hook only checks the final reply, so English text before a question dialog is never caught. Decide whether to add the check."
  landed
  ask "質問の前にも言語判定を走らせる?"
  jq -e '.hookSpecificOutput.permissionDecisionReason | test("英語")' <<< "$output"
}

@test "denies a question whose text is too long" {
  user "どうする？"
  claude "$EXPLAIN"
  ask "degen-para から依頼です。 AskUserQuestion の直前に書かれた英語の文章が、チェックされずにあなたに見えてしまうとのことです。 進めますか?"
  jq -e '.hookSpecificOutput.permissionDecisionReason | test("質問文が長い")' <<< "$output"
}

@test "lets an English explanation through on an English turn" {
  user "what should we do about the hook?"
  claude "The reply-language hook only checks the final reply, so English text before a question dialog is never caught. Decide whether to add the check."
  landed
  ask "Add the check?"
  [ -z "$output" ]
}

@test "skips the text checks when the transcript has not caught up" {
  user "どうする？"
  result
  ask "質問の前にも言語判定を走らせる?"
  [ -z "$output" ]
}
