#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/one-command-per-reply.sh"

transcript() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"hi"}}' \
    "$(jq -nc --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}')" > "$T"
}
input() { jq -nc --arg t "$T" --argjson a "${1:-false}" '{session_id:"s",stop_hook_active:$a,transcript_path:$t}'; }
two=$'First:\n\n```bash\njust aws-login\n```\n\nThen:\n\n```bash\njust secret aws sandbox\n```'

@test "two bash blocks in the desktop app: blocks" {
  transcript "$two"
  CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'2 shell code blocks'* ]]
}

@test "sh and zsh blocks count too" {
  transcript $'```sh\nls\n```\n\n```zsh\npwd\n```'
  CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
}

@test "one bash block, or other languages beside it: passes" {
  transcript $'Run:\n\n```bash\njust aws-login\n```\n\n```ts\nconst a = 1\n```\n\n```json\n{}\n```'
  CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outside the desktop app: passes" {
  transcript "$two"
  CLAUDE_CODE_ENTRYPOINT=cli run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
  env -u CLAUDE_CODE_ENTRYPOINT "$HOOK" <<< "$(input)" > "$BATS_TEST_TMPDIR/out"
  [ ! -s "$BATS_TEST_TMPDIR/out" ]
}

@test "the second stop after a block: passes" {
  transcript "$two"
  CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input true)"
  [ -z "$output" ]
}

@test "one block followed by an ask to report back: blocks" {
  for ask in '済んだら知らせてください。' '出力を貼ってください。' 'Let me know when it is done.'; do
    transcript $'Run:\n\n```bash\njust secret aws sandbox\n```\n\n'"$ask"
    CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input)"
    [[ "$output" == *'report back'* ]]
  done
}

@test "an ask before the block, or none after it: passes" {
  transcript $'済んだら次へ進みます。\n\n```bash\njust secret aws sandbox\n```\n\nThis sends the key.'
  CLAUDE_CODE_ENTRYPOINT=claude-desktop run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}
