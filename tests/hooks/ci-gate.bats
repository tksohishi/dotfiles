#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  mkdir -p "$CLAUDE_CI_GATE_DIR" "$BATS_TEST_TMPDIR/bin"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export CI_GATE_WAIT_INTERVAL=0 CI_GATE_WAIT_MAX=0
  MARKER="$CLAUDE_CI_GATE_DIR/sid-1.json"
  unset CLAUDE_CODE_ENTRYPOINT
  fake_actions_status operational
}

fake_actions_status() {
  printf '#!/usr/bin/env bash\necho %s\n' "'{\"components\":[{\"name\":\"Actions\",\"status\":\"$1\"}]}'" > "$BATS_TEST_TMPDIR/bin/curl"
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
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
make_marker() { jq -nc --arg cwd "$BATS_TEST_TMPDIR" --argjson blocks "${1:-0}" --argjson at "${2:-$(date +%s)}" '{cwd:$cwd,sha:"abc1234def",blocks:$blocks,pushedAt:$at}' > "$MARKER"; }
push_workflow() { mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"; printf 'on:\n  push:\n' > "$BATS_TEST_TMPDIR/.github/workflows/ci.yml"; }
input() { echo '{"session_id":"sid-1","stop_hook_active":false}'; }

IN_PROGRESS='[{"databaseId":42,"workflowName":"CI","status":"in_progress","conclusion":""}]'
QUEUED='[{"databaseId":42,"workflowName":"CI","status":"queued","conclusion":""}]'
GREEN='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"success"}]'
RED='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"failure"}]'

@test "no marker: passes silently" {
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no run past the wait bound: reports CI did not run once and clears the marker" {
  make_marker; push_workflow; fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'GitHub created no Actions run'* ]]
  [ ! -e "$MARKER" ]
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}

@test "no run long after the push: stops waiting before the wait bound" {
  make_marker 0 $(( $(date +%s) - 600 )); push_workflow; fake_gh '[]'
  export CI_GATE_WAIT_MAX=60
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'GitHub created no Actions run'* ]]
  [ "$(gh_calls)" = "1" ]
}

@test "no run while Actions is degraded: stops waiting and names the status" {
  make_marker; push_workflow; fake_gh '[]'; fake_actions_status degraded_performance
  export CI_GATE_WAIT_MAX=60
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'githubstatus Actions: degraded_performance'* ]]
  [ "$(gh_calls)" = "1" ]
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

@test "in-progress run while Actions is degraded: reports unverified once and clears the marker" {
  make_marker; fake_gh "$IN_PROGRESS"; fake_actions_status degraded_performance
  export CI_GATE_WAIT_MAX=60
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'unverified'* ]]
  [[ "$output" == *'githubstatus Actions: degraded_performance'* ]]
  [ ! -e "$MARKER" ]
  [ "$(gh_calls)" = "1" ]
}

@test "unhealthy Actions in the CLI: shows a systemMessage without blocking" {
  make_marker; push_workflow; fake_gh '[]'; fake_actions_status degraded_performance
  export CLAUDE_CODE_ENTRYPOINT=cli
  run "$HOOK" <<< "$(input)"
  [ "$(echo "$output" | jq -r '.systemMessage')" != null ]
  [ "$(echo "$output" | jq -r '.decision')" = null ]
  [ ! -e "$MARKER" ]
}

@test "red run in the CLI: still blocks" {
  make_marker; fake_gh "$RED"
  export CLAUDE_CODE_ENTRYPOINT=cli
  run "$HOOK" <<< "$(input)"
  [ "$(echo "$output" | jq -r '.decision')" = block ]
}

@test "runs still queued long after the push: reports unverified once and clears the marker" {
  make_marker 0 $(( $(date +%s) - 600 )); fake_gh "$QUEUED"
  export CI_GATE_WAIT_MAX=60
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'unverified'* ]]
  [ ! -e "$MARKER" ]
  [ "$(gh_calls)" = "1" ]
}

@test "queued run shortly after the push: keeps waiting and keeps the marker" {
  make_marker; fake_gh "$QUEUED"
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'gh run watch <id> --exit-status (ids: 42)'* ]]
  [ "$(jq -r .blocks "$MARKER")" = "1" ]
}

@test "red run while Actions is degraded: still reports red" {
  make_marker; fake_gh "$RED"; fake_actions_status major_outage
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'CI is RED'* ]]
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

@test "no runs and the pushed branch is outside push.branches: clears the marker silently" {
  jq -nc --arg cwd "$BATS_TEST_TMPDIR" '{cwd:$cwd,sha:"abc1234def",branches:["feature"],blocks:0,pushedAt:0}' > "$MARKER"
  mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"
  printf 'on:\n  push:\n    branches: [main]\n' > "$BATS_TEST_TMPDIR/.github/workflows/ci.yml"
  fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}

@test "no runs and the pushed branch is in push.branches: still reports CI did not run" {
  jq -nc --arg cwd "$BATS_TEST_TMPDIR" '{cwd:$cwd,sha:"abc1234def",branches:["main"],blocks:0,pushedAt:0}' > "$MARKER"
  mkdir -p "$BATS_TEST_TMPDIR/.github/workflows"
  printf 'on:\n  push:\n    branches: [main]\n' > "$BATS_TEST_TMPDIR/.github/workflows/ci.yml"
  fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [[ "$output" == *'GitHub created no Actions run'* ]]
}
