#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/replace-dollar.sh"
# split so this file's own content does not trip the hook when it is written
W='Bun.''write(f, s)'
WS='writeFile''Sync(f, s)'

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

write_input() {
  jq -n --arg c "$1" '{tool_input: {content: $c}}'
}

@test "blocks a string replacement in a script that writes the file" {
  run "$HOOK" <<< "$(bash_input "s = s.replace(a, b); await $W")"
  [ "$status" -eq 2 ]
  [[ "$output" == *"replace-dollar"* ]]
}

@test "blocks a template replacement with the sync writer" {
  run "$HOOK" <<< "$(bash_input 's.replace(a, `$${y}`); '"$WS")"
  [ "$status" -eq 2 ]
}

@test "blocks when the first argument is a call" {
  run "$HOOK" <<< "$(bash_input "s.replace(fn(a, c), b); $W")"
  [ "$status" -eq 2 ]
}

@test "blocks in Write content" {
  run "$HOOK" <<< "$(write_input "let s = t.replace(a, b)
await $W")"
  [ "$status" -eq 2 ]
}

@test "passes a function replacement" {
  run "$HOOK" <<< "$(bash_input "s = s.replace(a, () => b); await $W")"
  [ "$status" -eq 0 ]
}

@test "passes a function replacement with a parameter" {
  run "$HOOK" <<< "$(bash_input "s = s.replaceAll(a, m => m); $W")"
  [ "$status" -eq 0 ]
}

@test "passes split and join" {
  run "$HOOK" <<< "$(bash_input "s.split(a).join(b); $W")"
  [ "$status" -eq 0 ]
}

@test "passes a replacement in a script that writes no file" {
  run "$HOOK" <<< "$(bash_input 'console.log(s.replace(a, b))')"
  [ "$status" -eq 0 ]
}
