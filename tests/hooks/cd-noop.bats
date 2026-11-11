#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/cd-noop.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/src"
}

input() {
  jq -n --arg cmd "$1" --arg cwd "$REPO" '{tool_input: {command: $cmd}, cwd: $cwd}'
}

denied() {
  run "$HOOK" <<< "$(input "$1")"
  [ "$status" -eq 0 ]
  [[ "$output" == *deny* ]]
}

allowed() {
  run "$HOOK" <<< "$(input "$1")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies cd to the working directory before &&" {
  denied "cd $REPO && git status"
  [[ "$output" == *"already in"* ]]
}

@test "denies cd to the working directory before ;" {
  denied "cd $REPO; ls"
}

@test "denies cd on its own first line of a multi-line command" {
  denied "cd $REPO
git status"
}

@test "denies quoted and trailing-slash forms" {
  denied "cd \"$REPO\" && ls"
  denied "cd '$REPO/' && ls"
}

@test "denies cd . and pushd" {
  denied "cd . && ls"
  denied "pushd $REPO && ls"
}

@test "denies a path that resolves through a symlink" {
  ln -s "$REPO" "$BATS_TEST_TMPDIR/link"
  denied "cd $BATS_TEST_TMPDIR/link && ls"
}

@test "allows cd to a subdirectory" {
  allowed "cd src && ls"
  allowed "cd $REPO/src && ls"
}

@test "allows cd elsewhere and bare cd" {
  allowed "cd $BATS_TEST_TMPDIR && ls"
  allowed "cd $REPO"
}

@test "allows a cd that is not the first command" {
  allowed "ls && cd $REPO && ls"
}

@test "allows commands without cd and unresolvable targets" {
  allowed "git status"
  allowed 'cd "$DIR" && ls'
  allowed "cd $REPO/missing && ls"
}
