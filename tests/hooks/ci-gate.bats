#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  mkdir -p "$CLAUDE_CI_GATE_DIR" "$BATS_TEST_TMPDIR/bin"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export CI_GATE_WAIT_INTERVAL=0 CI_GATE_MARKER_WAIT=1
  REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  SHA=$(git -C "$REPO" rev-parse HEAD)
  MARKER="$CLAUDE_CI_GATE_DIR/sid-1.json"
  printf '#!/usr/bin/env bash\necho %s\n' "'{\"components\":[{\"name\":\"Actions\",\"status\":\"operational\"}]}'" > "$BATS_TEST_TMPDIR/bin/curl"
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
make_marker() { jq -nc --arg cwd "$REPO" --arg sha "${2:-$SHA}" --argjson at "${1:-$(date +%s)}" '{cwd:$cwd,sha:$sha,pushedAt:$at}' > "$MARKER"; }
input() { jq -nc --arg cwd "$REPO" --arg cmd "${1:-git push}" '{session_id:"sid-1",cwd:$cwd,tool_input:{command:$cmd}}'; }

IN_PROGRESS='[{"databaseId":42,"workflowName":"CI","status":"in_progress","conclusion":""}]'
QUEUED='[{"databaseId":42,"workflowName":"CI","status":"queued","conclusion":""}]'
GREEN='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"success"}]'
RED='[{"databaseId":42,"workflowName":"CI","status":"completed","conclusion":"failure"}]'

@test "not a push: exits silently without calling gh" {
  make_marker; fake_gh "$RED"
  run "$HOOK" <<< "$(input "git status")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" = 0 ]
}

@test "push with no marker (no workflow runs for it): exits silently" {
  fake_gh "$RED"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" = 0 ]
}

@test "marker for another SHA: exits silently" {
  make_marker "" deadbeef; fake_gh "$RED"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" = 0 ]
}

@test "all green: exits 0 silently and clears the marker" {
  make_marker; fake_gh "$GREEN"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$MARKER" ]
}

@test "red: exits 2 with report-it-red and clears the marker" {
  make_marker; fake_gh "$RED"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *'did NOT all pass: CI (42): failure'* ]]
  [[ "$output" == *'CI is RED'* ]]
  [ ! -e "$MARKER" ]
}

@test "in progress, then green: polls and exits 0" {
  make_marker; fake_gh '[]' "$QUEUED" "$IN_PROGRESS" "$GREEN"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" = 4 ]
}

@test "in progress, then red: exits 2" {
  make_marker; fake_gh "$IN_PROGRESS" "$RED"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *'CI is RED'* ]]
}

@test "no run long after the push: exits 2 unverified with the Actions status" {
  make_marker $(( $(date +%s) - 600 )); fake_gh '[]'
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *'GitHub created no Actions run'*'githubstatus Actions: operational'*'unverified'* ]]
  [ ! -e "$MARKER" ]
}

@test "runs still queued long after the push: exits 2 unverified" {
  make_marker $(( $(date +%s) - 600 )); fake_gh "$QUEUED"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *'never started (CI (42))'* ]]
}

@test "in progress past the wait bound: exits 2 unverified" {
  make_marker; fake_gh "$IN_PROGRESS"
  CI_GATE_WAIT_MAX=0 run "$HOOK" <<< "$(input)"
  [ "$status" -eq 2 ]
  [[ "$output" == *'still running after'* ]]
}

@test "a newer push replacing the marker stops the watcher silently" {
  make_marker; fake_gh "$IN_PROGRESS"
  printf '#!/usr/bin/env bash\njq -c ".sha = \\"newer\\"" "%s" > "%s.tmp" && mv "%s.tmp" "%s"\necho %s\n' \
    "$MARKER" "$MARKER" "$MARKER" "$MARKER" "'$IN_PROGRESS'" > "$BATS_TEST_TMPDIR/bin/gh"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r .sha "$MARKER")" = newer ]
}
