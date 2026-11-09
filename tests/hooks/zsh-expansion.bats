#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/zsh-expansion.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "blocks a flag expansion over a file read" {
  run "$HOOK" <<< "$(bash_input 'bun x.ts ${(f)"$(<a.txt)"}')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"zsh-expansion"* ]]
}

@test "blocks forced word splitting" {
  run "$HOOK" <<< "$(bash_input 'bun x.ts ${=seed}')"
  [ "$status" -eq 2 ]
}

@test "blocks a file read inside a substitution" {
  run "$HOOK" <<< "$(bash_input 'echo $(<a.txt)')"
  [ "$status" -eq 2 ]
}

@test "allows plain variables and substitutions" {
  run "$HOOK" <<< "$(bash_input 'echo ${HOME} $(date) ${#arr[@]}')"
  [ "$status" -eq 0 ]
}

@test "allows a file path passed to a script" {
  run "$HOOK" <<< "$(bash_input 'bun x.ts a.txt')"
  [ "$status" -eq 0 ]
}

@test "ignores non-Bash input" {
  run "$HOOK" <<< '{"tool_input":{"content":"${(f)x}"}}'
  [ "$status" -eq 0 ]
}
