#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  mkdir -p "$CLAUDE_CI_GATE_DIR" "$BATS_TEST_TMPDIR/bin"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export CI_GATE_WAIT_INTERVAL=0 CI_GATE_WAIT_MAX=0
  MARKER="$CLAUDE_CI_GATE_DIR/sid-1.json"
}

# Fake gh: each `gh run list` call prints the next argument; the last one repeats.
fake_gh() {
  local i=0
  : > "$BATS_TEST_TMPDIR/gh-calls"
  rm -rf "$BATS_TEST_TMPDIR/gh-responses"; mkdir -p "$BATS_TEST_TMPDIR/gh-responses"
  for r in "$@"; do i=$((i + 1)); printf '%s\n' "$r" > "$BATS_TEST_TMPDIR/gh-responses/$i"; done
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<SH
#!/usr/bin/env bash
dir="$BATS_TEST_TMPDIR/gh-responses"; log="$BATS_TEST_TMPDIR/gh-calls"
echo x >> "\$log"; n=\$(wc -l < "\$log" | tr -d ' ')
[ -f "\$dir/\$n" ] || n=$i
cat "\$dir/\$n"
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}
gh_calls() { wc -l < "$BATS_TEST_TMPDIR/gh-calls" | tr -d ' '; }
make_marker() { jq -nc --arg cwd "$BATS_TEST_TMPDIR" --argjson blocks "${1:-0}" '{cwd:$cwd,sha:"abc1234def",blocks:$blocks}' > "$MARKER"; }
push_workflow() { mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"; printf 'on:\n  push:\n' > "$BATS_TEST_TMPDIR/.github/workflows/ci.yml"; }
input() { echo '{"session_id":"sid-1","stop_hook_active":false}'; }

IN_PROGRESS='[{"databaseId":42,"workflowName":"CI","status":"in_progress","conclusion":""}]'
GREEN='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"success"}]'
RED='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"failure"}]'

@test "no marker: passes silently" {
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no runs yet past the wait bound: blocks and keeps the marker" {
  make_marker; push_workflow; fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'no Actions runs found yet'* ]]
  [ -f "$MARKER" ]
}

@test "no runs and no push-triggered workflow: clears the marker silently without waiting" {
  make_marker; fake_gh '[]'
  mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"
  printf 'on:\n  issues:\n    types: [opened]\n' > "$BATS_TEST_TMPDIR/.github/workflows/issues.yml"
  export CI_GATE_WAIT_MAX=5
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
  [ "$(gh_calls)" = "1" ]
}

@test "in-progress run past the wait bound: blocks with the run id and keeps the marker" {
  make_marker; fake_gh "$IN_PROGRESS"
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'gh run watch <id> --exit-status (ids: 42)'* ]]
  [ "$(jq -r .blocks "$MARKER")" = "1" ]
}

@test "in-progress run that finishes within the wait bound: polls, then passes silently" {
  make_marker; push_workflow; fake_gh '[]' "$IN_PROGRESS" "$GREEN"
  export CI_GATE_WAIT_MAX=5
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
  [ "$(gh_calls)" = "3" ]
}

@test "in-progress run that turns red within the wait bound: blocks with report-it-red" {
  make_marker; fake_gh "$IN_PROGRESS" "$RED"
  export CI_GATE_WAIT_MAX=5
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'CI is RED'* ]]
  [ ! -e "$MARKER" ]
}

@test "all green: passes silently and clears the marker" {
  make_marker; fake_gh '[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"success"},{"databaseId":43,"workflowName":"Deploy","status":"completed","conclusion":"success"}]'
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}

@test "red run: blocks once with report-it-red and clears the marker" {
  make_marker; fake_gh "$RED"
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'CI is RED'* ]]
  [[ "$output" == *'CI (42): failure'* ]]
  [ ! -e "$MARKER" ]
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}

@test "bounded: after 12 blocks the marker is dropped and the turn may end" {
  make_marker 12; fake_gh "$IN_PROGRESS"
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}
