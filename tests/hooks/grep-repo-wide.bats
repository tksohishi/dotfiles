#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/grep-repo-wide.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/src"
  git -C "$REPO" init -q
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

@test "denies grep -rn over the current directory" {
  denied 'grep -rn foo .'
  [[ "$output" == *"Use rg instead"* ]]
}

@test "denies grep -r with no path" {
  denied 'grep -r foo'
}

@test "denies combined flags and quoted pattern" {
  denied "grep -Rin 'foo bar' ./"
}

@test "denies --recursive with --include" {
  denied "grep --recursive --include='*.ts' foo ."
}

@test "denies grep -r over the repo toplevel" {
  denied "grep -rn foo $REPO"
}

@test "denies grep -r after cd and &&" {
  denied 'cd /somewhere && grep -rn foo . | head'
}

@test "denies grep -r with -e pattern and no path" {
  denied 'grep -r -e foo'
}

@test "allows grep -r over a subdirectory" {
  allowed 'grep -rn foo src/ docs/'
}

@test "allows grep -r with -A argument and a subdirectory" {
  allowed 'grep -rn -A 3 foo src'
}

@test "allows non-recursive grep in a pipeline" {
  allowed 'cat x | grep -n foo'
}

@test "allows piped grep -r with no path (reads stdin)" {
  allowed 'cat x | grep -r foo'
}

@test "allows grep on files" {
  allowed 'grep -n foo justfile package.json'
}

@test "separators inside quotes do not split" {
  allowed "grep -n 'a | grep -r b .' file.txt"
}

@test "redirect 2>&1 does not split" {
  allowed 'grep -rn foo src 2>&1 | head'
}

@test "denies bare git grep" {
  denied 'git grep -n foo'
}

@test "denies git -C dir grep with root pathspec" {
  denied 'git -C /x grep foo -- .'
}

@test "allows git grep with a revision" {
  allowed 'git grep foo HEAD~3'
}

@test "allows git grep with a pathspec" {
  allowed 'git grep -n foo -- docs/'
}

@test "allows rg" {
  allowed 'rg -n foo .'
}

@test "allows commands without grep" {
  allowed 'ls -la'
}
