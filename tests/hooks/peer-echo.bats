#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/peer-echo.ts"

setup() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : > "$T"
  ANSWER="V4のレッグはHeron5にまだ無く、見積もりとレーン生成と状態追従もV4分は未着手。フック付きプールは対象外にして最初はフック無しに絞る。838dのV4レッグ669のうち290がフック付き。作業はコントラクト、テスト、impl-review、デプロイの順で、最初の本番は11/16月曜が現実的。MetricはPyth Pro署名が要るので後回し。"
}

user() { jq -nc --arg s "$1" '{type:"user",message:{role:"user",content:$s}}' >> "$T"; }
send() { jq -nc --arg m "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",name:"SendMessage",input:{to:"degen-heron",message:$m}}]}}' >> "$T"; }
stop() { run bun "$HOOK" <<< "$(jq -nc --arg t "$T" --arg m "$1" '{hook_event_name:"Stop",transcript_path:$t,last_assistant_message:$m,stop_hook_active:false}')"; }

@test "blocks a reply that retells the peer's answer" {
  user "Another Claude session sent a message: <cross-session-message from-name=\"degen-heron\">$ANSWER</cross-session-message>"
  stop "heron から答えが来ました。 $ANSWER"
  jq -e '.decision == "block" and (.reason | contains("届いたメッセージ"))' <<< "$output"
}

@test "passes a one-line pointer plus this session's own take" {
  user "Another Claude session sent a message: <cross-session-message from-name=\"degen-heron\">$ANSWER</cross-session-message>"
  stop "degen-heron から V4 の見積もりが返りました（全文は heron 側）。 私は11/16で賛成です。 ただし月曜の朝は板が薄いので、最初の1時間は上限額を半分にして始めるのがよいと考えます。 次は、上限額を下げた設定を用意して、日曜の夜に heron と時刻を合わせます。 Metric の再検討は V4の結果を3日分見てからにします。"
  [ -z "$output" ]
}

@test "blocks a reply that repeats what this turn sent" {
  user "heron に聞いて"
  send "$ANSWER"
  stop "degen-heron に送りました。 $ANSWER"
  jq -e '.decision == "block" and (.reason | contains("送った本文"))' <<< "$output"
}

@test "ignores a turn the user started" {
  user "$ANSWER"
  stop "$ANSWER"
  [ -z "$output" ]
}

@test "a background task notice ends the peer turn" {
  user "<cross-session-message from-name=\"degen-heron\">$ANSWER</cross-session-message>"
  user "<task-notification>done</task-notification>"
  stop "$ANSWER"
  [ -z "$output" ]
}
