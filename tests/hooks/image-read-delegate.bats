#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/image-read-delegate.sh"

setup() {
  export CLAUDE_IMAGE_READ_STATE_DIR="$BATS_TEST_TMPDIR/state"
}

# $1 file_path, $2 session_id (optional), $3 extra JSON object to merge (optional)
read_input() {
  jq -n --arg p "$1" --arg s "${2:-sess-default}" --argjson extra "${3:-{\}}" \
    '{session_id: $s, tool_input: {file_path: $p}} * $extra'
}

denied() {
  echo "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
}

@test "allows non-image reads" {
  run "$HOOK" <<<"$(read_input '/repo/src/MapScreen.swift')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies a png read from the main agent" {
  run "$HOOK" <<<"$(read_input '/repo/tmp/_ws-detail.png')"
  [ "$status" -eq 0 ]
  denied "$output"
}

@test "deny reason names the file and tells the agent to delegate" {
  run "$HOOK" <<<"$(read_input '/repo/tmp/_pin-badge.png')"
  echo "$output" | grep -q '_pin-badge.png'
  echo "$output" | grep -qi 'subagent'
}

@test "denies every raster extension, case-insensitively" {
  for ext in png jpg jpeg gif webp bmp tif tiff heic heif PNG JPG HEIC; do
    run "$HOOK" <<<"$(read_input "/repo/shot.$ext" "sess-$ext")"
    denied "$output" || {
      echo "extension not blocked: $ext"
      return 1
    }
  done
}

@test "ignores svg and pdf" {
  run "$HOOK" <<<"$(read_input '/repo/icon.svg')"
  [ -z "$output" ]
  run "$HOOK" <<<"$(read_input '/repo/spec.pdf')"
  [ -z "$output" ]
}

@test "allows when agent_id marks a subagent" {
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-a' '{"agent_id":"agent-abc"}')"
  [ -z "$output" ]
}

@test "allows when agent_type marks a subagent" {
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-b' '{"agent_type":"Explore"}')"
  [ -z "$output" ]
}

@test "allows when transcript_path points into subagents/" {
  extra='{"transcript_path":"/p/1ec52d79/subagents/agent-a81c.jsonl"}'
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-c' "$extra")"
  [ -z "$output" ]
}

@test "loop guard: second read of the same path in a session is allowed" {
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-guard')"
  denied "$output"
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-guard')"
  [ -z "$output" ]
}

@test "loop guard is per path, not blanket" {
  run "$HOOK" <<<"$(read_input '/repo/one.png' 'sess-two')"
  denied "$output"
  run "$HOOK" <<<"$(read_input '/repo/two.png' 'sess-two')"
  denied "$output"
}

@test "loop guard is per session" {
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-x')"
  denied "$output"
  run "$HOOK" <<<"$(read_input '/repo/shot.png' 'sess-y')"
  denied "$output"
}

@test "survives a missing file_path" {
  run "$HOOK" <<<'{"session_id":"s","tool_input":{}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handles spaces in the path" {
  run "$HOOK" <<<"$(read_input '/repo/My Screens/shot one.png' 'sess-sp')"
  denied "$output"
}
