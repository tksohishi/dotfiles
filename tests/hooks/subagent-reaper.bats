#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/subagent-reaper.sh"

setup() {
  export SUBAGENT_REAPER_TASKS_ROOT="$BATS_TEST_TMPDIR/root"
  TASKS="$SUBAGENT_REAPER_TASKS_ROOT/proj/sess/tasks"
  mkdir -p "$TASKS"
  T="$BATS_TEST_TMPDIR/agent.jsonl"
  : > "$T"
}

teardown() {
  for p in "$BATS_TEST_TMPDIR"/*.pid; do [ -f "$p" ] && kill -- "-$(cat "$p")" 2>/dev/null; done
  return 0
}

# a group-leading writer of tasks/<id>.output, like the harness's shell wrapper
start_shell() {
  bash -c 'set -m; sleep 300 > "$1" & echo $! > "$2"' _ "$TASKS/$1.output" "$BATS_TEST_TMPDIR/$1.pid"
  cat "$BATS_TEST_TMPDIR/$1.pid"
}

own() { jq -nc --arg id "$1" '{type:"user",toolUseResult:{stdout:"",backgroundTaskId:$id}}' >> "$T"; }

make_input() {
  jq -nc --arg t "$T" '{hook_event_name:"SubagentStop",agent_transcript_path:$t,
    background_tasks:[$ARGS.positional[] | {id:., type:"shell", status:"running"}]}' --args "$@"
}

alive() { kill -0 "$1" 2>/dev/null; }
wait_dead() { for _ in 1 2 3 4 5 6 7 8 9 10; do alive "$1" || return 0; sleep 0.1; done; return 1; }

@test "kills a running shell the subagent started, sparing a tail -f reader of its output" {
  pid=$(start_shell b1)
  bash -c 'set -m; tail -f "$1" > /dev/null & echo $! > "$2"' _ "$TASKS/b1.output" "$BATS_TEST_TMPDIR/reader.pid"
  reader=$(cat "$BATS_TEST_TMPDIR/reader.pid")
  own b1
  run "$HOOK" <<< "$(make_input b1)"
  [ "$status" -eq 0 ]
  wait_dead "$pid"
  alive "$reader"
}

@test "ignores a background announcement that is only printed text" {
  pid=$(start_shell b2)
  jq -nc '{type:"user",toolUseResult:{stdout:"Command running in background with ID: b2. Output is being written to: x"}}' >> "$T"
  run "$HOOK" <<< "$(make_input b2)"
  [ "$status" -eq 0 ]
  alive "$pid"
}

@test "leaves an owned id alone when background_tasks does not list it as running" {
  pid=$(start_shell b3)
  own b3
  run "$HOOK" <<< "$(make_input other)"
  [ "$status" -eq 0 ]
  alive "$pid"
}

@test "passes silently without a transcript" {
  run "$HOOK" <<< '{"agent_transcript_path":"/nonexistent","background_tasks":[]}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
