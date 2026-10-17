#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/code-comment-nudge.sh"

edit_input() {
  jq -n --arg f "$1" --arg old "$2" --arg new "$3" \
    '{tool_name: "Edit", tool_input: {file_path: $f, old_string: $old, new_string: $new, replace_all: false}}'
}

write_input() {
  jq -n --arg f "$1" --arg c "$2" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}}'
}

@test "silent on code without comments" {
  run "$HOOK" <<< "$(edit_input /p/a.ts 'const a = 1;' 'const a = 2;')"
  [ -z "$output" ]
}

@test "silent on a single full-line comment" {
  run "$HOOK" <<< "$(edit_input /p/a.ts 'x();' $'// keep: API rejects batches over 100\nx();')"
  [ -z "$output" ]
}

@test "nudges on two added full-line comments" {
  run "$HOOK" <<< "$(edit_input /p/a.ts 'x();' $'// first\n// second\nx();')"
  [[ "$output" == *"added 2 comment line(s)"* ]]
}

@test "nudges on any trailing comment" {
  run "$HOOK" <<< "$(edit_input /p/a.ts 'return a;' 'return a; // the answer')"
  [[ "$output" == *"1 trailing comment(s)"* ]]
}

@test "counts block comment lines in C-style files" {
  run "$HOOK" <<< "$(write_input /p/a.ts $'/**\n * Does a thing.\n */\nexport const a = 1;\n')"
  [[ "$output" == *"added 3 comment line(s)"* ]]
}

@test "uses # for python and shell" {
  run "$HOOK" <<< "$(write_input /p/a.py $'# one\n# two\nx = 1\n')"
  [[ "$output" == *"added 2 comment line(s)"* ]]
}

@test "ignores comments already in old_string" {
  run "$HOOK" <<< "$(edit_input /p/a.ts $'// one\n// two\nx(1);' $'// one\n// two\nx(2);')"
  [ -z "$output" ]
}

@test "ignores shebang and pragmas" {
  run "$HOOK" <<< "$(write_input /p/a.sh $'#!/bin/bash\n# shellcheck disable=SC2034\nx=1\n')"
  [ -z "$output" ]
}

@test "ignores markers inside strings" {
  run "$HOOK" <<< "$(edit_input /p/a.sh 'x' 'echo "a # b"')"
  [ -z "$output" ]
}

@test "ignores URLs" {
  run "$HOOK" <<< "$(edit_input /p/a.ts 'x' 'fetch(url, "https://example.com");')"
  [ -z "$output" ]
}

@test "ignores bash length expansion" {
  run "$HOOK" <<< "$(edit_input /p/a.sh 'x' 'n=${#arr[@]}')"
  [ -z "$output" ]
}

@test "skips non-code files" {
  run "$HOOK" <<< "$(write_input /p/README.md $'# Title\n# Other\n')"
  [ -z "$output" ]
}
