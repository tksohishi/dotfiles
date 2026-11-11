#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/markdown-size.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/docs/mirror"
  git -C "$REPO" init -q
  LONG=$(printf 'x%.0s' $(seq 1 1200))
}

run_on() {
  run "$HOOK" <<< "$(jq -n --arg f "$1" '{tool_input: {file_path: $f}}')"
  [ "$status" -eq 0 ]
}

@test "warns on a long prose line" {
  printf '# T\n\n%s\n' "$LONG" > "$REPO/docs/a.md"
  run_on "$REPO/docs/a.md"
  [[ "$output" == *additionalContext* ]]
  [[ "$output" == *"over 1000 characters"* ]]
  [[ "$output" == *"line 3"* ]]
}

@test "ignores long lines in code fences and tables" {
  printf '```\n%s\n```\n| %s |\n' "$LONG" "$LONG" > "$REPO/docs/a.md"
  run_on "$REPO/docs/a.md"
  [ -z "$output" ]
}

@test "warns on a large file" {
  for i in $(seq 1 500); do echo "line $i $(printf 'y%.0s' $(seq 1 90))"; done > "$REPO/docs/big.md"
  run_on "$REPO/docs/big.md"
  [[ "$output" == *"bytes (over 40000)"* ]]
}

@test "skips files hidden by .ignore" {
  echo 'docs/mirror/' > "$REPO/.ignore"
  printf '%s\n' "$LONG" > "$REPO/docs/mirror/a.md"
  run_on "$REPO/docs/mirror/a.md"
  [ -z "$output" ]
}

@test "skips gitignored files" {
  echo 'tmp/' > "$REPO/.gitignore"
  mkdir -p "$REPO/tmp"
  printf '%s\n' "$LONG" > "$REPO/tmp/a.md"
  run_on "$REPO/tmp/a.md"
  [ -z "$output" ]
}

@test "skips files outside a git repo" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  printf '%s\n' "$LONG" > "$BATS_TEST_TMPDIR/plain/a.md"
  run_on "$BATS_TEST_TMPDIR/plain/a.md"
  [ -z "$output" ]
}

@test "skips non-markdown files" {
  printf '%s\n' "$LONG" > "$REPO/a.txt"
  run_on "$REPO/a.txt"
  [ -z "$output" ]
}

@test "quiet for a normal file" {
  printf '# T\n\nShort line.\n' > "$REPO/docs/a.md"
  run_on "$REPO/docs/a.md"
  [ -z "$output" ]
}
