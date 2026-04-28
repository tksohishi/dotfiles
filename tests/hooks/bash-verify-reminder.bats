#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotclaude/hooks/bash-verify-reminder.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "reminds after brew install with package name" {
  run "$HOOK" <<< "$(bash_input 'brew install jq')"
  [[ "$output" == *"brew list | grep jq"* ]]
}

@test "reminds after brew install with trailing flag" {
  run "$HOOK" <<< "$(bash_input 'brew install --formula')"
  [[ "$output" == *"brew list"* ]]
}

@test "reminds after rm" {
  run "$HOOK" <<< "$(bash_input 'rm -f /tmp/x')"
  [[ "$output" == *"the rm'd path"* ]]
}

@test "reminds after git commit" {
  run "$HOOK" <<< "$(bash_input 'git commit -m foo')"
  [[ "$output" == *"git log -1"* ]]
}

@test "reminds after git push" {
  run "$HOOK" <<< "$(bash_input 'git push origin main')"
  [[ "$output" == *"git status"* ]]
}

@test "reminds after launchctl load" {
  run "$HOOK" <<< "$(bash_input 'launchctl load /Library/LaunchAgents/com.foo.bar.plist')"
  [[ "$output" == *"launchctl list | grep com.foo.bar"* ]]
}

@test "reminds after uv python install" {
  run "$HOOK" <<< "$(bash_input 'uv python install 3.13')"
  [[ "$output" == *"uv python list --only-installed"* ]]
}

@test "reminds after uv add" {
  run "$HOOK" <<< "$(bash_input 'uv add ruff')"
  [[ "$output" == *"uv tree"* ]]
}

@test "reminds after defaults write" {
  run "$HOOK" <<< "$(bash_input 'defaults write com.foo Bar -bool true')"
  [[ "$output" == *"defaults read com.foo Bar"* ]]
}

@test "no reminder for plain ls" {
  run "$HOOK" <<< "$(bash_input 'ls')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
