#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/agent-followup-context.sh"

setup() {
  WORK="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$WORK"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"user","message":{"role":"user","content":"My fruit is mangosteen"}}' > "$T"
}

say() {
  jq -nc --arg s "$1" '{type:"user",message:{role:"user",content:$s}}' >> "$T"
}

spawn() {
  jq -nc --arg t "$T" --arg c "$WORK" --arg n "$1" \
    '{session_id:"s1",transcript_path:$t,cwd:$c,hook_event_name:"PreToolUse",tool_name:"Agent",tool_input:{name:$n,prompt:"go"}}'
}

send() {
  jq -nc --arg t "$T" --arg c "$WORK" --arg to "$1" \
    '{session_id:"s1",transcript_path:$t,cwd:$c,hook_event_name:"PreToolUse",tool_name:"SendMessage",tool_input:{to:$to,summary:"x",message:"next step"}}'
}

@test "spawning a named agent records a baseline and prints nothing" {
  run "$HOOK" <<< "$(spawn probe)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$WORK/tmp/agent-context/sent/s1/probe" ]
}

@test "a send appends only what the user said since the spawn" {
  "$HOOK" <<< "$(spawn probe)"
  say "My color is teal"
  run "$HOOK" <<< "$(send probe)"
  msg=$(jq -r '.hookSpecificOutput.updatedInput.message' <<< "$output")
  [[ "$msg" == "next step"* ]]
  [[ "$msg" == *"User:"*"My color is teal"* ]]
  [[ "$msg" != *mangosteen* ]]
  [ "$(jq -r '.hookSpecificOutput.updatedInput.to' <<< "$output")" = "probe" ]
  [ "$(jq -r '.hookSpecificOutput.updatedInput.summary' <<< "$output")" = "x" ]
}

@test "the next send carries only the newer turns" {
  "$HOOK" <<< "$(spawn probe)"
  say "My color is teal"
  "$HOOK" <<< "$(send probe)" >/dev/null
  say "My city is Lisbon"
  run "$HOOK" <<< "$(send probe)"
  msg=$(jq -r '.hookSpecificOutput.updatedInput.message' <<< "$output")
  [[ "$msg" == *Lisbon* ]]
  [[ "$msg" != *teal* ]]
}

@test "nothing new since the last send leaves the message alone" {
  "$HOOK" <<< "$(spawn probe)"
  run "$HOOK" <<< "$(send probe)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "recipients not spawned by name here are left alone" {
  say "My color is teal"
  run "$HOOK" <<< "$(send other-session)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "structured protocol messages are left alone" {
  "$HOOK" <<< "$(spawn probe)"
  say "My color is teal"
  input=$(send probe | jq -c '.tool_input.message = {type:"shutdown_request"}')
  run "$HOOK" <<< "$input"
  [ -z "$output" ]
}
