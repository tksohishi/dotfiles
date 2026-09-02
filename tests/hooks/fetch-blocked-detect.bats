#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/fetch-blocked-detect.sh"

hook_input() {
  # $1 tool name, $2 command (Bash only), $3 tool_response text
  jq -n --arg tool "$1" --arg cmd "$2" --arg resp "$3" \
    '{tool_name: $tool, tool_input: (if $tool == "Bash" then {command: $cmd} else {url: "https://example.com"} end), tool_response: $resp}'
}

assert_injects() {
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("fetch-blocked")' >/dev/null
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "WebFetch result with Cloudflare challenge injects the escalation instruction" {
  run "$HOOK" <<< "$(hook_input WebFetch '' '<title>Just a moment...</title>')"
  assert_injects
}

@test "WebFetch result with 403 injects" {
  run "$HOOK" <<< "$(hook_input WebFetch '' 'HTTP/1.1 403 Forbidden')"
  assert_injects
}

@test "WebFetch hook-deny message injects" {
  run "$HOOK" <<< "$(hook_input WebFetch '' 'denied by blocked-domains hook')"
  assert_injects
}

@test "clean WebFetch result stays silent" {
  run "$HOOK" <<< "$(hook_input WebFetch '' '<html><body>Welcome</body></html>')"
  assert_silent
}

@test "httpie Bash fetch returning 429 injects" {
  run "$HOOK" <<< "$(hook_input Bash "http GET https://example.com/x --ignore-stdin" 'HTTP/1.1 429 Too Many Requests')"
  assert_injects
}

@test "agent-browser Bash call hitting Press and Hold injects" {
  run "$HOOK" <<< "$(hook_input Bash "agent-browser open https://zillow.com" 'Press & Hold to confirm you are a human')"
  assert_injects
}

@test "Bash command that is not a fetch stays silent even when output mentions a block" {
  run "$HOOK" <<< "$(hook_input Bash "rg -i captcha tmp/page.html" 'Access Denied - captcha required')"
  assert_silent
}

@test "structured tool_response object is inspected" {
  run "$HOOK" <<< "$(jq -n '{tool_name: "WebFetch", tool_input: {url: "https://example.com"}, tool_response: {status: 406, body: "Not Acceptable"}}')"
  assert_injects
}

@test "empty input exits cleanly" {
  run "$HOOK" <<< '{}'
  assert_silent
}
