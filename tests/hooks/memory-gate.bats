#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/memory-gate.sh"
MEM="/Users/me/.claude/projects/-foo/memory"

make_write() { jq -nc --arg fp "$1" --arg c "$2" '{tool_input:{file_path:$fp,content:$c}}'; }
make_edit()  { jq -nc --arg fp "$1" --arg c "$2" '{tool_input:{file_path:$fp,new_string:$c}}'; }

@test "denies feedback-type write to memory dir" {
  run "$HOOK" <<< "$(make_write "$MEM/x.md" $'---\nname: t\ntype: feedback\n---')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies config-value write (settings.json key:value)" {
  run "$HOOK" <<< "$(make_write "$MEM/x.md" $'---\ntype: project\n---\n`dotclaude/settings.json` has `effortLevel: "xhigh"`')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies config-value asserted via Edit new_string" {
  run "$HOOK" <<< "$(make_edit "$MEM/MEMORY.md" 'settings.json `model` is `"claude-fable-5"`')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "passes project-type non-config write (no gating)" {
  run "$HOOK" <<< "$(make_write "$MEM/x.md" $'---\ntype: project\n---\nBacklog: migrate the widget pipeline')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes MEMORY.md index edit (no type, non-config)" {
  run "$HOOK" <<< "$(make_edit "$MEM/MEMORY.md" '- [Foo](foo.md) — bar')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "config-file mention without a value assertion passes, not denies" {
  run "$HOOK" <<< "$(make_write "$MEM/x.md" $'---\ntype: project\n---\nConfig lives at .config/mise/config.toml, symlinked')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes (no output) for write outside memory dir" {
  run "$HOOK" <<< "$(make_write "/Users/me/some/random.md" $'---\ntype: feedback\n---')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
