#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/ci-gate-record.sh"

setup() {
  export CLAUDE_CI_GATE_DIR="$BATS_TEST_TMPDIR/ci-gate"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.github/workflows"
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
