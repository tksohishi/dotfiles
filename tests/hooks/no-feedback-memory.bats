#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/no-feedback-memory.sh"

make_input() {
  printf '{"tool_input":{"file_path":"%s","content":"---\\nname: t\\ndescription: x\\ntype: %s\\n---"}}' "$1" "$2"
}

@test "denies feedback-type write to memory dir" {
  run "$HOOK" <<< "$(make_input /Users/me/.claude/projects/-foo/memory/x.md feedback)"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "passes project-type write to memory dir" {
  run "$HOOK" <<< "$(make_input /Users/me/.claude/projects/-foo/memory/x.md project)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes user-type write to memory dir" {
  run "$HOOK" <<< "$(make_input /Users/me/.claude/projects/-foo/memory/x.md user)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes feedback-type write outside memory dir" {
  run "$HOOK" <<< "$(make_input /Users/me/some/random.md feedback)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes write to MEMORY.md (no type frontmatter)" {
  input='{"tool_input":{"file_path":"/Users/me/.claude/projects/-foo/memory/MEMORY.md","content":"# Index\n- [Foo](foo.md) — bar"}}'
  run "$HOOK" <<< "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
