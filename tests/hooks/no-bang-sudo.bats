#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/no-bang-sudo.sh"

transcript() {
  T="$BATS_TEST_TMPDIR/t.jsonl"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"hi"}}' \
    "$(jq -nc --arg t "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$t}]}}')" > "$T"
}
input() { jq -nc --arg t "$T" --argjson a "${1:-false}" '{session_id:"s",stop_hook_active:$a,transcript_path:$t}'; }

@test "! sudo line: blocks" {
  transcript $'Run:\n\n! sudo dscacheutil -flushcache'
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "block"'* ]]
  [[ "$output" == *'own terminal'* ]]
}

@test "! with interactive tool (ssh-add, passwd, gcloud auth login): blocks" {
  for cmd in 'ssh-add ~/.ssh/id_ed25519' 'passwd' 'gcloud auth login'; do
    transcript $'Try:\n  ! '"$cmd"
    run "$HOOK" <<< "$(input)"
    [[ "$output" == *'"decision": "block"'* ]]
  done
}

@test "! with login/secret commands: blocks" {
  for cmd in 'wrangler secret put API_KEY' 'gh auth login' 'docker login ghcr.io' 'aws configure' 'op signin' 'npm login'; do
    transcript $'Then:\n! '"$cmd"
    run "$HOOK" <<< "$(input)"
    [[ "$output" == *'"decision": "block"'* ]]
  done
}

@test "stdin supplied via pipe or redirect: passes" {
  for cmd in 'echo "$V" | wrangler secret put API_KEY' 'wrangler secret put API_KEY < key.txt' 'echo "$T" | docker login ghcr.io -u me --password-stdin'; do
    transcript $'Then:\n! '"$cmd"
    run "$HOOK" <<< "$(input)"
    [ -z "$output" ]
  done
}

@test "! with a non-interactive command: passes silently" {
  for cmd in 'bunx wrangler whoami' 'gh auth status' 'wrangler secret list' 'docker ps' 'npm install'; do
    transcript $'Check with:\n\n! '"$cmd"
    run "$HOOK" <<< "$(input)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "sudo mentioned without the ! prefix: passes" {
  transcript 'Run sudo dscacheutil -flushcache in your own terminal.'
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}

@test "only the last assistant message counts" {
  transcript $'! sudo foo'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"ok"}}' \
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Done, run it in your terminal."}]}}' >> "$T"
  run "$HOOK" <<< "$(input)"
  [ -z "$output" ]
}

@test "stop_hook_active: passes (loop guard)" {
  transcript $'! sudo foo'
  run "$HOOK" <<< "$(input true)"
  [ -z "$output" ]
}

@test "missing transcript: passes" {
  T="$BATS_TEST_TMPDIR/nope.jsonl"
  run "$HOOK" <<< "$(input)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
