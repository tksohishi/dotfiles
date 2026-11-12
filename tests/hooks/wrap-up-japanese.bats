#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/wrap-up-japanese.ts"

setup() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : > "$T"
}

user() { jq -nc --arg s "$1" '{type:"user",message:{role:"user",content:$s}}' >> "$T"; }
wrap() { run bun "$HOOK" <<< "$(jq -nc --arg t "$T" --argjson ti "$1" '{hook_event_name:"PreToolUse",tool_name:"mcp__ccd_turn__wrap_up",transcript_path:$t,tool_input:$ti}')"; }

@test "denies an English recap on a Japanese turn" {
  user "進めて"
  wrap '{"recap":"Moved the hooks to dotfiles","actions":[{"label":"コミットする"}]}'
  [ "$status" -eq 0 ]
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"
}

@test "passes a Japanese box" {
  user "進めて"
  wrap '{"recap":"hook を dotfiles に移しました","ask":"コミットしますか？","actions":[{"label":"OK"}]}'
  [ -z "$output" ]
}

@test "passes English on an English turn" {
  user "please move the hooks"
  wrap '{"recap":"Moved the hooks to dotfiles"}'
  [ -z "$output" ]
}
