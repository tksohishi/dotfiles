#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/git-remote-ssh.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

denied() { [ "$status" -eq 0 ] && [[ "$output" == *'"permissionDecision":"deny"'* ]]; }
allowed() { [ "$status" -eq 0 ] && [ -z "$output" ]; }

@test "denies git remote add with an HTTPS GitHub URL" {
  run "$HOOK" <<< "$(bash_input 'git remote add origin https://github.com/owner/repo.git')"
  denied
}

@test "denies git remote set-url with an HTTPS GitHub URL" {
  run "$HOOK" <<< "$(bash_input 'git -C /x/y remote set-url origin https://github.com/owner/repo.git')"
  denied
}

@test "denies an HTTPS remote add inside a && chain" {
  run "$HOOK" <<< "$(bash_input 'git remote rename origin old && git remote add origin https://github.com/owner/repo.git')"
  denied
}

@test "allows an SSH GitHub remote" {
  run "$HOOK" <<< "$(bash_input 'git remote add origin git@github.com:owner/repo.git')"
  allowed
}

@test "allows cloning over HTTPS" {
  run "$HOOK" <<< "$(bash_input 'git clone https://github.com/owner/repo tmp/repo')"
  allowed
}

@test "allows an HTTPS remote on another host" {
  run "$HOOK" <<< "$(bash_input 'git remote add up https://gitlab.com/owner/repo.git')"
  allowed
}

@test "ignores a GitHub URL in a later, unrelated segment" {
  run "$HOOK" <<< "$(bash_input 'git remote -v; echo https://github.com/owner/repo')"
  allowed
}
