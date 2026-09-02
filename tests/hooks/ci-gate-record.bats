#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate-record.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.github/workflows"
  printf 'on:\n  push:\n' > "$REPO/.github/workflows/ci.yml"
  git -C "$REPO" init -q
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  SHA=$(git -C "$REPO" rev-parse HEAD)
}

make_input() { jq -nc --arg cwd "$REPO" --arg cmd "$1" '{session_id:"sid-1",cwd:$cwd,tool_input:{command:$cmd}}'; }

@test "records HEAD after a git push" {
  run "$HOOK" <<< "$(make_input "git push -q")"
  [ "$status" -eq 0 ]
  [ "$(jq -r .sha "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "$SHA" ]
  [ "$(jq -r .blocks "$CLAUDE_CI_GATE_DIR/sid-1.json")" = "0" ]
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
  for wf in 'on: push' 'on: [issues, pull_request]' $'on:\n  push:\n    branches: [main]' $'"on":\n  - issues\n  - push' $'on:\n  pull_request:'; do
    rm -f "$CLAUDE_CI_GATE_DIR/sid-1.json" "$REPO/.github/workflows/"*
    printf '%s\n' "$wf" > "$REPO/.github/workflows/ci.yml"
    run "$HOOK" <<< "$(make_input "git push")"
    [ -f "$CLAUDE_CI_GATE_DIR/sid-1.json" ]
  done
}
