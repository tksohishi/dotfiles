#!/usr/bin/env bats
#
# This file must not contain a literal emdash or section sign anywhere, same
# rule as the script under test. Build them at runtime from their UTF-8 bytes.

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/no-prose-symbols.sh"
DASH=$(printf '\xe2\x80\x94')
SECT=$(printf '\xc2\xa7')

make_write() { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$fp,content:$c}}'; }
make_edit()  { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Edit",tool_input:{file_path:$fp,new_string:$c}}'; }

@test "denies emdash in a publish-bound path" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/drafts/post.md" "a b $DASH c d")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"Emdash"* ]]
}

@test "denies section sign in a publish-bound path" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/posts/x.md" "see $SECT 3 below")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"Section sign"* ]]
}

@test "deny reason carries an excerpt so the offending spot is findable" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/drafts/post.md" "lead in $DASH trailing text")"
  [[ "$output" == *"Excerpt"* ]]
  [[ "$output" == *"trailing text"* ]]
}

@test "denies via Edit new_string, not just Write content" {
  run "$HOOK" <<< "$(make_edit "/Users/me/blog/drafts/post.md" "x $DASH y")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"new_string"* ]]
}

@test "passes clean prose in a publish-bound path" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/drafts/post.md" "a plain sentence, nothing fancy")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allowlist model: emdash outside a publish path passes" {
  run "$HOOK" <<< "$(make_write "/Users/me/work/notes/scratch.md" "a $DASH b")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extension gate: non-prose file inside a publish tree passes" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/drafts/build.ts" "const a = 1 $DASH 2")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "basename glob DRAFT* fires anywhere" {
  run "$HOOK" <<< "$(make_write "/tmp/DRAFT-announcement.md" "a $DASH b")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "exclusion wins over an inclusion match" {
  run "$HOOK" <<< "$(make_write "/Users/me/blog/drafts/RETRO.md" "a $DASH b")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "tools other than Write/Edit/NotebookEdit are ignored" {
  run "$HOOK" <<< "$(jq -nc --arg c "a $DASH b" '{tool_name:"Bash",tool_input:{command:$c}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "registry patterns are whitespace-trimmed (inclusion and exclusion)" {
  cp "$HOOK" "$BATS_TEST_TMPDIR/hook.sh"
  printf '   /padded/   \n\t!PADEXCL.md\t\n' > "$BATS_TEST_TMPDIR/prose-publish-paths.txt"

  run "$BATS_TEST_TMPDIR/hook.sh" <<< "$(make_write "/x/padded/a.md" "a $DASH b")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]

  run "$BATS_TEST_TMPDIR/hook.sh" <<< "$(make_write "/x/padded/PADEXCL.md" "a $DASH b")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no per-line forks in the registry loops" {
  # The loops run for every markdown edit and the hook has a 5s timeout, so
  # trimming must stay parameter expansion. `$(echo ... | xargs)` here cost
  # 76 fork+execs per edit and blew the timeout under load.
  # Comments name it deliberately, so only executable lines count.
  run bash -c "grep -v '^[[:space:]]*#' '$HOOK' | grep 'xargs' || true"
  [ -z "$output" ]
}
