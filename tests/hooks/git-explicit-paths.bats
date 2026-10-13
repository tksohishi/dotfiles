#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/git-explicit-paths.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

allows() {
  run "$HOOK" <<< "$(bash_input "$1")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

denies() {
  run "$HOOK" <<< "$(bash_input "$1")"
  [ "$status" -eq 0 ]
  [[ "$output" == *deny* ]]
}

@test "ignores non-git commands" {
  allows 'ls -la'
  allows 'git status --short'
}

@test "allows git add with named files" {
  allows 'git add foo.ts bar/baz.md'
  allows 'git -C /repo add src/a.ts'
}

@test "denies sweeping git add forms" {
  denies 'git add -A'
  denies 'git add --all'
  denies 'git add .'
  denies 'git add -u'
  denies 'git add --update'
  denies 'git add :/'
  denies 'git add -Av'
  denies 'git -C /repo add .'
}

@test "allows git commit with -- paths" {
  allows 'git commit -m "Fix thing" -- foo.ts'
  allows 'git commit -m "Subject" -m "- why" -- a.ts b.ts'
  allows 'git add new.ts && git commit -m "Add new" -- new.ts && git push -q origin main'
  allows 'git commit --amend --no-edit -- foo.ts'
}

@test "denies git commit without paths" {
  denies 'git commit -m "Fix thing"'
  denies 'git add foo.ts && git commit -m "Fix thing"'
  denies 'git commit --amend --no-edit'
}

@test "denies git commit -a forms" {
  denies 'git commit -a -m "x" -- foo.ts'
  denies 'git commit -am "x"'
  denies 'git commit --all -m "x"'
  denies 'git commit -m "x" -- .'
}

@test "separators and flags inside the message do not confuse it" {
  allows 'git commit -m "Run -a; then git add . && done" -- foo.ts'
  allows "git commit -m 'Use -A && .' -- foo.ts"
  denies 'git commit -m "mentions -- foo.ts"'
}

@test "message mentioning git add . is not a git add" {
  allows 'echo "git add ." > notes.txt'
}
