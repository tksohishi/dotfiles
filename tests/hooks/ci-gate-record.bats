#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate-record.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.github/workflows"
  printf 'on:\n  push:\n' > "$REPO/.github/workflows/ci.yml"
  git -C "$REPO" init -q -b main
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git init -q --bare "$BATS_TEST_TMPDIR/remote.git"
  git -C "$REPO" remote add origin "$BATS_TEST_TMPDIR/remote.git"
  git -C "$REPO" push -q -u origin HEAD
  SHA=$(git -C "$REPO" rev-parse HEAD)
  mkdir -p "$BATS_TEST_TMPDIR/bin"; export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  open_prs 0
}

# Fake gh: `gh pr list ... --jq length` prints the given open-PR count.
open_prs() { printf '#!/usr/bin/env bash\necho %s\n' "$1" > "$BATS_TEST_TMPDIR/bin/gh"; chmod +x "$BATS_TEST_TMPDIR/bin/gh"; }

push_branch() {
  git -C "$REPO" switch -q -c "$1"
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m "$1"
  git -C "$REPO" push -q -u origin "$1"
  SHA=$(git -C "$REPO" rev-parse HEAD)
}

unpushed_commit() {
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m next
  SHA=$(git -C "$REPO" rev-parse HEAD)
}

make_input() { jq -nc --arg cwd "$REPO" --arg cmd "$1" '{session_id:"sid-1",cwd:$cwd,tool_input:{command:$cmd}}'; }

@test "records HEAD after a git push" {
  run "$HOOK" <<< "$(make_input "git push -q")"
  [ "$status" -eq 0 ]
  [ "$(jq -r .sha "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "$SHA" ]
  [ "$(jq -r .blocks "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "0" ]
  [ "$(jq -r '.pushedAt | type' "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "number" ]
}

@test "matches a push inside a && chain" {
  run "$HOOK" <<< "$(make_input "git commit -q -m x && git push origin main")"
  [ -f "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "ignores commands that are not a push" {
  run "$HOOK" <<< "$(make_input "git status --short")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "ignores repos without workflows" {
  rm -r "$REPO/.github"
  run "$HOOK" <<< "$(make_input "git push")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "ignores repos whose only workflow is not push-triggered" {
  rm "$REPO/.github/workflows/ci.yml"
  printf 'on:\n  issues:\n    types: [opened]\n' > "$REPO/.github/workflows/issues.yml"
  printf 'on: [schedule, workflow_dispatch]\n' > "$REPO/.github/workflows/nightly.yaml"
  printf 'on:\n  pull_request_target:\n' > "$REPO/.github/workflows/prt.yml"
  run "$HOOK" <<< "$(make_input "git push")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "records when any workflow has a push or pull_request trigger" {
  open_prs 1
  for wf in 'on: push' 'on: [issues, pull_request]' $'on:\n  push:\n    branches: [main]' $'"on":\n  - issues\n  - push' $'on:\n  pull_request:'; do
    rm -f "$CLAUDE_CI_GATE_DIR/sid-1.json" "$REPO/.github/workflows/"*
    printf '%s\n' "$wf" > "$REPO/.github/workflows/ci.yml"
    run "$HOOK" <<< "$(make_input "git push")"
    [ -f "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
  done
}

@test "ignores a push that did not reach the remote" {
  unpushed_commit
  run "$HOOK" <<< "$(make_input "git push")"
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "drops a stale marker for the same unpushed SHA" {
  unpushed_commit
  mkdir -p "$CLAUDE_CI_GATE_DIR"
  jq -nc --arg cwd "$REPO" --arg sha "$SHA" '{cwd:$cwd,sha:$sha,blocks:5}' > "$CLAUDE_CI_GATE_DIR/sid-1.json"
  run "$HOOK" <<< "$(make_input "git push")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "keeps the marker of an earlier pushed SHA when a later push fails" {
  run "$HOOK" <<< "$(make_input "git push")"
  PUSHED=$SHA
  unpushed_commit
  run "$HOOK" <<< "$(make_input "git push")"
  [ "$(jq -r .sha "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "$PUSHED" ]
}

@test "records the pushed branch" {
  run "$HOOK" <<< "$(make_input "git push")"
  [ "$(jq -c .branches "$CLAUDE_CI_GATE_DIR/sid-1.json")" = '["main"]' ]
}

@test "ignores a push to a branch outside push.branches" {
  printf 'on:\n  push:\n    branches: [main]\n' > "$REPO/.github/workflows/ci.yml"
  push_branch feature
  run "$HOOK" <<< "$(make_input "git push")"
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "records a push to a branch matching a push.branches glob" {
  printf 'on:\n  push:\n    branches:\n      - main\n      - "release/**"\n' > "$REPO/.github/workflows/ci.yml"
  push_branch release/1.2
  run "$HOOK" <<< "$(make_input "git push")"
  [ "$(jq -r .sha "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "$SHA" ]
}

@test "honors branches-ignore and tags-only push filters" {
  printf 'on:\n  push:\n    branches-ignore: [wip/*]\n' > "$REPO/.github/workflows/ci.yml"
  printf 'on:\n  push:\n    tags: [v*]\n' > "$REPO/.github/workflows/release.yml"
  push_branch wip/x
  run "$HOOK" <<< "$(make_input "git push")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}

@test "pull_request-only workflow: records only when the branch has an open PR" {
  printf 'on:\n  push:\n    branches: [main]\n  pull_request:\n' > "$REPO/.github/workflows/ci.yml"
  push_branch feature
  run "$HOOK" <<< "$(make_input "git push")"
  [ ! -e "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
  open_prs 1
  run "$HOOK" <<< "$(make_input "git push")"
  [ -f "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
}
