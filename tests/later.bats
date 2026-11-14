#!/usr/bin/env bats

LATER="$BATS_TEST_DIRNAME/../bin/later"

setup() {
  P="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$P/tmp/heron/refund-hint"
  git -C "$P" init -q
  mkdir -p "$P/.agents/later" && printf 'heron the trading app\nlib shared code\nops hosts and costs\n' > "$P/.agents/later/scopes"
  cd "$P"
}

@test "adds and lists an item" {
  run "$LATER" add heron/refund-hint --what "refund を先読みする" --why "レースを拾う" --when "Pulse 契約後" --see tmp/heron/refund-hint
  [ "$status" -eq 0 ]
  [[ "$output" == "added "*"heron/refund-hint: refund を先読みする | why: レースを拾う | when: Pulse 契約後 | see: tmp/heron/refund-hint" ]]
  run "$LATER" ls heron
  [[ "$output" == *"heron/refund-hint"* ]]
}

@test "requires what and why" {
  run "$LATER" add heron/x --what "a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--why is required"* ]]
}

@test "rejects a scope outside the list and a bad topic" {
  run "$LATER" add misc/x --what a --why b
  [ "$status" -eq 1 ]
  [[ "$output" == *"not in .agents/later/scopes"* ]]
  run "$LATER" add heron/Bad_Topic --what a --why b
  [[ "$output" == *"bad slug"* ]]
}

@test "uses main without a scope list" {
  trash .agents/later/scopes
  run "$LATER" add main/thing --what a --why b
  [ "$status" -eq 0 ]
}

@test "rejects overlong text counting CJK as two columns" {
  long=$(printf 'あ%.0s' $(seq 1 81))
  run "$LATER" add heron/x --what "$long" --why b
  [ "$status" -eq 1 ]
  [[ "$output" == *"162 columns"* ]]
}

@test "rejects a see path that does not exist" {
  run "$LATER" add heron/x --what a --why b --see tmp/nope
  [[ "$output" == *"does not exist"* ]]
}

@test "refuses a second open item with the same slug" {
  "$LATER" add heron/x --what a --why b
  run "$LATER" add heron/x --what c --why d
  [[ "$output" == *"already open"* ]]
}

@test "orders by tag and filters" {
  "$LATER" add heron/a --what a --why b
  "$LATER" add heron/b --what a --why b --tag P1
  "$LATER" add heron/c --what a --why b --tag P0 --when later
  run "$LATER" ls heron
  [[ "${lines[0]}" == P0* && "${lines[1]}" == P1* && "${lines[2]}" == *heron/a* ]]
  run "$LATER" ls --waiting
  [ "${#lines[@]}" -eq 1 ]
  run "$LATER" ls --tag none --json
  [ "$(echo "$output" | jq length)" -eq 1 ]
}

@test "edits, clears when, and retags" {
  "$LATER" add heron/a --what a --why b --when w
  run "$LATER" edit heron/a --what new --when ""
  [[ "$output" == *"heron/a: new | why: b" ]]
  run "$LATER" tag heron/a P0
  [[ "$output" == *"P2 -> P0"* ]]
  run "$LATER" tag heron/a P2
  [[ "$output" == *"P0 -> P2"* ]]
  run "$LATER" tag heron/a P3
  [ "$status" -eq 1 ]
}

@test "done hides an item and undo reopens it" {
  "$LATER" add heron/a --what a --why b
  run "$LATER" done heron/a --note "shipped"
  [[ "$output" == "done heron/a"* ]]
  run "$LATER" ls
  [ "$output" = "(none)" ]
  run "$LATER" ls --closed
  [[ "$output" == *"done "*": shipped"* ]]
  run "$LATER" undo heron/a
  [[ "$output" == "reopened"* ]]
  "$LATER" add heron/b --what a --why b
  "$LATER" drop heron/b
  run "$LATER" add heron/b --what again --why b
  [ "$status" -eq 0 ]
}

@test "keeps an earlier date and rejects a future or malformed one" {
  run "$LATER" add heron/a --what a --why b --date 2026-10-25
  [[ "$output" == "added 10-25 heron/a"* ]]
  run "$LATER" add heron/b --what a --why b --date 2999-01-01
  [[ "$output" == *"not in the future"* ]]
  run "$LATER" add heron/b --what a --why b --date 10/25
  [ "$status" -eq 1 ]
}

@test "works from a subdirectory" {
  mkdir -p sub
  cd sub
  run "$LATER" add lib/feed-retry --what a --why b
  [ "$status" -eq 0 ]
  [ -f "$P/tmp/backlog.db" ]
}

@test "adds and removes a scope, and refuses to remove one with open items" {
  run "$LATER" scope add stargazer --what "the Stargazer app"
  [ "$status" -eq 0 ]
  run "$LATER" scopes
  [[ "$output" == *$'stargazer\tthe Stargazer app'* && "$output" == *$'heron\tthe trading app'* ]]
  run "$LATER" add stargazer/first --what a --why b
  [ "$status" -eq 0 ]
  run "$LATER" scope rm stargazer
  [ "$status" -eq 1 ]
  [[ "$output" == *"1 open item"* ]]
  run "$LATER" done stargazer/first
  run "$LATER" scope rm stargazer
  [ "$status" -eq 0 ]
  run "$LATER" scope add heron --what dup
  [[ "$output" == *"already exists"* ]]
}

@test "uses the main checkout's backlog and scopes from a worktree" {
  git -C "$P" add .agents/later/scopes
  git -C "$P" -c user.name=t -c user.email=t@example.com commit -qm init -- .agents/later/scopes
  git -C "$P" worktree add -q "$BATS_TEST_TMPDIR/wt"
  printf 'heron the trading app\nonly-in-main x\n' > "$P/.agents/later/scopes"
  cd "$BATS_TEST_TMPDIR/wt"
  run "$LATER" add only-in-main/thing --what a --why b
  [ "$status" -eq 0 ]
  [ -f "$P/tmp/backlog.db" ]
  [ ! -e "$BATS_TEST_TMPDIR/wt/tmp/backlog.db" ]
}
