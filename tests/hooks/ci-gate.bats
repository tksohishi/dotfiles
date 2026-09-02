#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  mkdir -p "$CLAUDE_CI_GATE_DIR" "$BATS_TEST_TMPDIR/bin"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  MARKER="$CLAUDE_CI_GATE_DIR/sid-1.json"
}

# Fake gh: `gh run list ...` prints whatever $1 holds
fake_gh() {
  printf '#!/usr/bin/env bash\ncat <<"JSON"\n%s\nJSON\n' "$1" > "$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}
make_marker() { jq -nc --arg cwd "$BATS_TEST_TMPDIR" --argjson blocks "${1:-0}" '{cwd:$cwd,sha:"abc1234def",blocks:$blocks}' > "$MARKER"; }
push_workflow() { mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"; printf 'on:\n  push:\n' > "$BATS_TEST_TMPDIR/.github/workflows/ci.yml"; }
input() { echo '{"session_id":"sid-1","stop_hook_active":false}'; }

@test "no marker: passes silently" {
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no runs yet: blocks and keeps the marker" {
  make_marker; push_workflow; fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'no Actions runs found yet'* ]]
  [ -f "$MARKER" ]
}

@test "no runs and no push-triggered workflow: clears the marker silently" {
  make_marker; fake_gh '[]'
  mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"
  printf 'on:\n  issues:\n    types: [opened]\n' > "$BATS_TEST_TMPDIR/.github/workflows/issues.yml"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}

@test "in-progress run: blocks with the run id and keeps the marker" {
  make_marker; fake_gh '[{"databaseId":42,"workflowName":"CI","status":"in_progress","conclusion":""}]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'gh run watch <id> --exit-status (ids: 42)'* ]]
  [ "$(jq -r .blocks "$MARKER")" = "1" ]
}

@test "all green: passes silently and clears the marker" {
  make_marker; fake_gh '[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"success"},{"databaseId":43,"workflowName":"Deploy","status":"completed","conclusion":"success"}]'
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}

@test "red run: blocks once with report-it-red and clears the marker" {
  make_marker; fake_gh '[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"failure"}]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'CI is RED'* ]]
  [[ "$output" == *'CI (42): failure'* ]]
  [ ! -e "$MARKER" ]
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}

@test "bounded: after 12 blocks the marker is dropped and the turn may end" {
  make_marker 12; fake_gh '[{"databaseId":42,"workflowName":"CI","status":"in_progress","conclusion":""}]'
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}
