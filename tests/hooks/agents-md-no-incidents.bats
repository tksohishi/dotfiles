#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/agents-md-no-incidents.sh"

edit() {
  jq -nc --arg f "$1" --arg o "$2" --arg n "$3" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}'
}

denied() { jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"; }

@test "denies an added line with an MM/DD date" {
  run "$HOOK" <<< "$(edit /r/AGENTS.md "- Rule A." $'- Rule A.\n- Rule B (10/30: the race was lost).')"
  [ "$status" -eq 0 ]
  denied
  [[ "$output" == *"10/30"* ]]
}

@test "denies an ISO date and a commit hash" {
  run "$HOOK" <<< "$(edit /r/CLAUDE.md "" "- See 2026-11-12 and commit d75a6d0.")"
  denied
  [[ "$output" == *2026-11-12* && "$output" == *d75a6d0* ]]
}

@test "leaves dates already in the file alone" {
  run "$HOOK" <<< "$(edit /r/AGENTS.md $'- Old (10/30).\n- Rule A.' $'- Old (10/30).\n- Rule A, reworded.')"
  [ -z "$output" ]
}

@test "allows a clean rule and ignores other files" {
  run "$HOOK" <<< "$(edit /r/AGENTS.md "" "- Never push to main without CI.")"
  [ -z "$output" ]
  run "$HOOK" <<< "$(edit /r/docs/notes.md "" "- 10/30 race d75a6d0")"
  [ -z "$output" ]
}

@test "does not mistake paths, versions or plain hex words for dates or hashes" {
  run "$HOOK" <<< "$(edit /r/AGENTS.md "" "- Use src/a/b, v1.2/3 and the deadbeef marker; 24/7 coverage.")"
  [ -z "$output" ]
}

@test "checks only new lines of a Write" {
  f="$BATS_TEST_TMPDIR/AGENTS.md"
  printf -- '- Old (10/30).\n' > "$f"
  run "$HOOK" <<< "$(jq -nc --arg f "$f" '{tool_name:"Write",tool_input:{file_path:$f,content:"- Old (10/30).\n- New rule."}}')"
  [ -z "$output" ]
  run "$HOOK" <<< "$(jq -nc --arg f "$f" '{tool_name:"Write",tool_input:{file_path:$f,content:"- Old (10/30).\n- New (11/12)."}}')"
  denied
}

@test "checks added lines of a Codex apply_patch on AGENTS.md only" {
  patch=$'*** Begin Patch\n*** Update File: sub/AGENTS.md\n@@\n- old 10/30\n+ new rule (11/12)\n*** Update File: README.md\n+ 11/13 note\n*** End Patch'
  run "$HOOK" <<< "$(jq -nc --arg c "$patch" '{model:"gpt",tool_name:"apply_patch",tool_input:{command:$c}}')"
  denied
  [[ "$output" == *11/12* && "$output" != *11/13* && "$output" != *10/30* ]]
}
