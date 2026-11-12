#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/subagent-context.sh"

setup() {
  WORK="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$WORK"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  {
    echo '{"type":"user","isMeta":true,"message":{"role":"user","content":"<local-command-caveat>noise</local-command-caveat>"}}'
    echo '{"type":"user","message":{"role":"user","content":"<command-name>/clear</command-name>"}}'
    echo '{"type":"user","message":{"role":"user","content":"I want X because of Y<system-reminder>hidden</system-reminder>"}}'
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"secret"},{"type":"text","text":"Let us do Z."},{"type":"tool_use","name":"Bash","input":{}}]}}'
    echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"tool output"}]}}'
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Done."}]}}'
    echo '{"type":"user","isSidechain":true,"message":{"role":"user","content":"subagent prompt"}}'
  } > "$T"
}

payload() {
  jq -nc --arg t "$T" --arg c "$WORK" --arg a "$1" \
    '{hook_event_name:"SubagentStart",agent_id:"abc123",agent_type:$a,transcript_path:$t,cwd:$c}'
}

@test "inlines the labeled conversation for a general-purpose subagent" {
  run "$HOOK" <<< "$(payload general-purpose)"
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.hookEventName == "SubagentStart"' <<< "$output"
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" == *"User:"*"I want X because of Y"* ]]
  [[ "$ctx" == *"Claude:"*"Let us do Z."*"Done."* ]]
}

@test "drops reminders, tool traffic, thinking, command noise and sidechains" {
  run "$HOOK" <<< "$(payload general-purpose)"
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" != *hidden* ]]
  [[ "$ctx" != *"tool output"* ]]
  [[ "$ctx" != *secret* ]]
  [[ "$ctx" != *"/clear"* ]]
  [[ "$ctx" != *noise* ]]
  [[ "$ctx" != *"subagent prompt"* ]]
}

@test "writes a long conversation to tmp/agent-context and passes the path" {
  long=$(printf 'a%.0s' $(seq 1 9000))
  jq -nc --arg s "$long" '{type:"user",message:{role:"user",content:$s}}' >> "$T"
  run "$HOOK" <<< "$(payload general-purpose)"
  ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<< "$output")
  [[ "$ctx" == *"$WORK/tmp/agent-context/abc123.md"* ]]
  grep -q "I want X because of Y" "$WORK/tmp/agent-context/abc123.md"
}

@test "skips forks and lookup agents" {
  for a in fork web-fetch statusline-setup claude-code-guide; do
    run "$HOOK" <<< "$(payload "$a")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "no-op when the transcript is missing" {
  run "$HOOK" <<< '{"hook_event_name":"SubagentStart","agent_type":"general-purpose","transcript_path":"/nonexistent.jsonl","cwd":"/"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
