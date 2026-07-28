#!/usr/bin/env bats
#
# The hook guards Write/Edit content, so this file must not contain a literal
# spoof pattern anywhere. Every offending string is built at runtime from
# split fragments; keep it that way when adding cases.

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/no-bot-detection-bypass.sh"
WD="navigator.web""driver"
SPOOF="Object.defineProperty(Navigator.prototype, 'web""driver', { get: () ""=> undefined });"
DEL="delete navigator.__proto__.web""driver"
PLUGIN="puppeteer-extra-plugin-""stealth"
SOLVER="2""captcha.com"

make_write() { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$fp,content:$c}}'; }
make_bash()  { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

@test "denies a stealth script written to disk" {
  run "$HOOK" <<< "$(make_write "/tmp/x.js" "$SPOOF")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies the spoof property referenced from a Bash command" {
  run "$HOOK" <<< "$(make_bash "agent-browser eval \"$WD\"")"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies a stealth plugin install" {
  run "$HOOK" <<< "$(make_bash "pnpm add $PLUGIN")"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "denies a captcha-solving service" {
  run "$HOOK" <<< "$(make_bash "http POST https://$SOLVER/in.php")"
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "deny reason tells the agent to hand off to the user" {
  run "$HOOK" <<< "$(make_write "/tmp/s.js" "$DEL")"
  [[ "$output" == *"hand it over"* ]]
}

@test "allows ordinary browser automation" {
  run "$HOOK" <<< "$(make_bash "agent-browser click @e12")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows ordinary prose and code" {
  run "$HOOK" <<< "$(make_write "/tmp/notes.md" "filled the form and submitted it")"
  [ -z "$output" ]
}

@test "ignores tools it does not guard" {
  run "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.js"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
