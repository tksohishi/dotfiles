#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/no-instruction-attribution.sh"

make_write() { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$fp,content:$c}}'; }
make_edit()  { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Edit",tool_input:{file_path:$fp,new_string:$c}}'; }
make_patch() { jq -nc --arg p "$1" '{tool_name:"apply_patch",model:"gpt-5.5",tool_input:{patch:$p}}'; }

@test "denies (Name, Mon YYYY) attribution in AGENTS.md via Write" {
  run "$HOOK" <<< "$(make_write "/Users/me/proj/AGENTS.md" "- Never auto-branch (Takeshi, Aug 2026)")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"Takeshi, Aug 2026"* ]]
}

@test "denies attribution in CLAUDE.md via Edit new_string" {
  run "$HOOK" <<< "$(make_edit "/Users/me/proj/CLAUDE.md" "rule text (Takeshi, September 2026)")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies full-name attribution in SKILL.md" {
  run "$HOOK" <<< "$(make_edit "/Users/me/proj/.agents/skills/foo/SKILL.md" "do X (Takeshi Ohishi, Jan 2027)")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies attribution arriving via Codex apply_patch" {
  PATCH=$'*** Update File: AGENTS.md\n+- prefer pnpm (Takeshi, Aug 2026)'
  run "$HOOK" <<< "$(make_patch "$PATCH")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "passes clean rule text in AGENTS.md" {
  run "$HOOK" <<< "$(make_write "/Users/me/proj/AGENTS.md" "- Never auto-branch; work on main directly")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes attribution-shaped text outside instruction files" {
  run "$HOOK" <<< "$(make_write "/Users/me/proj/notes.md" "meeting notes (Takeshi, Aug 2026)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes plain parenthetical without a date" {
  run "$HOOK" <<< "$(make_write "/Users/me/proj/AGENTS.md" "use rsync (trailing slashes copy contents)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes month-year parenthetical without a name" {
  run "$HOOK" <<< "$(make_write "/Users/me/proj/AGENTS.md" "see the release notes (Aug 2026) for details")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes unrelated tools" {
  run "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"echo (Takeshi, Aug 2026) > AGENTS.md"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
