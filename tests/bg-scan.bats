#!/usr/bin/env bats

SCAN="$BATS_TEST_DIRNAME/../bin/bg-scan"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  REPO="$BATS_TEST_TMPDIR/repo"
  OTHER="$BATS_TEST_TMPDIR/other"
  mkdir -p "$REPO" "$OTHER"
}

slug() { (cd "$1" && pwd) | tr '/.' '--'; }

# $1 repo dir, $2 session id, then lines of JSON
transcript() {
  local dir="$HOME/.claude/projects/$(slug "$1")"
  mkdir -p "$dir"
  local f="$dir/$2.jsonl"
  shift 2
  printf '%s\n' "$@" > "$f"
}

create() { jq -nc --arg id "$1" --arg p "$2" '{type:"assistant", message:{content:[{type:"tool_use", id:$id, name:"CronCreate", input:{cron:"7,37 * * * *", prompt:$p, recurring:true}}]}}'; }
created() { jq -nc --arg id "$1" --arg job "$2" '{type:"user", message:{content:[{type:"tool_result", tool_use_id:$id, content:("Scheduled recurring job " + $job + " (7,37 * * * *). Session-only (not written to disk, dies when Claude exits).")}]}}'; }
fired() { jq -nc --arg ts "$1" --arg p "$2" '{type:"user", timestamp:$ts, message:{content:$p}}'; }
deleted() { jq -nc --arg job "$1" '{type:"assistant", message:{content:[{type:"tool_use", id:"d1", name:"CronDelete", input:{id:$job}}]}}'; }

cron_section() { sed -n '/^## CronCreate/,/^$/p' <<< "$output"; }

@test "an undeleted job is listed with its last fire time in New York time" {
  transcript "$REPO" s1 "$(create t1 'check races')" "$(created t1 ee80ff3b)" \
    "$(fired 2026-11-08T16:20:00.000Z 'check races')" "$(fired 2026-11-08T16:50:00.000Z 'check races')"
  run "$SCAN" --repo "$REPO"
  [ "$status" -eq 0 ]
  [[ "$(cron_section)" == *'ee80ff3b'*'session=s1'*'last fired 11/8 11:50'*'check races'* ]]
}

@test "a deleted job is not listed" {
  transcript "$REPO" s1 "$(create t1 'check races')" "$(created t1 aaaa1111)" "$(deleted aaaa1111)"
  run "$SCAN" --repo "$REPO"
  [[ "$(cron_section)" != *'aaaa1111'* ]]
  [[ "$(cron_section)" == *'none'* ]]
}

@test "a job that never fired says so" {
  transcript "$REPO" s1 "$(create t1 'check races')" "$(created t1 bbbb2222)"
  run "$SCAN" --repo "$REPO"
  [[ "$(cron_section)" == *'bbbb2222'*'never'* ]]
}

@test "--repo keeps only that repo's sessions; no argument shows both" {
  transcript "$REPO" s1 "$(create t1 'mine')" "$(created t1 cccc3333)"
  transcript "$OTHER" s2 "$(create t1 'theirs')" "$(created t1 dddd4444)"
  run "$SCAN" --repo "$REPO"
  [[ "$(cron_section)" == *'cccc3333'* ]]
  [[ "$(cron_section)" != *'dddd4444'* ]]
  [[ "$output" != *'## claude daemon'* ]]
  run "$SCAN"
  [[ "$(cron_section)" == *'cccc3333'* && "$(cron_section)" == *'dddd4444'* ]]
  [[ "$output" == *'## claude daemon'* ]]
}
