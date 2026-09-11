#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/env-example-secrets.sh"

# Fake keys built at runtime so no real-looking secret sits in the repo.
HEXKEY="0x$(printf 'ab%.0s' $(seq 1 32))"
MNEMONIC="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
B58="5Kb8kLf9zgWQnogidDA76MzPL6TsZZY36hWXMssSzNydYXYB9KF"

make_write() { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$fp,content:$c}}'; }
make_edit()  { jq -nc --arg fp "$1" --arg c "$2" '{tool_name:"Edit",tool_input:{file_path:$fp,old_string:"",new_string:$c}}'; }
make_bash()  { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

assert_deny()  { [ "$status" -eq 0 ]; [[ "$output" == *'"permissionDecision":"deny"'* ]]; }
assert_allow() { [ "$status" -eq 0 ]; [ -z "$output" ]; }

@test "denies a hex private key written to .env.example" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "RPC_URL=https://x
PRIVATE_KEY=$HEXKEY")"
  assert_deny
  [[ "$output" == *PRIVATE_KEY* ]]
}

@test "denies a prefixed key name (DEPLOYER_PRIVATE_KEY) in .env.sample" {
  run "$HOOK" <<< "$(make_write "/p/.env.sample" "DEPLOYER_PRIVATE_KEY=$HEXKEY")"
  assert_deny
}

@test "denies PK and PK_ prefixed names" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "PK=$HEXKEY")"
  assert_deny
  run "$HOOK" <<< "$(make_write "/p/.env.example" "PK_MAIN=$HEXKEY")"
  assert_deny
}

@test "denies a mnemonic" {
  run "$HOOK" <<< "$(make_write "/p/.env.template" "MNEMONIC=\"$MNEMONIC\"")"
  assert_deny
}

@test "denies a base58 wallet key via Edit" {
  run "$HOOK" <<< "$(make_edit "/p/.env.example" "WALLET_KEY=$B58")"
  assert_deny
}

@test "denies a PEM block" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "SIGNER_KEY=\"-----BEGIN EC PRIVATE KEY-----")"
  assert_deny
}

@test "denies a heredoc into .env.example from Bash" {
  run "$HOOK" <<< "$(make_bash "cat > .env.example <<'EOF'
PRIVATE_KEY=$HEXKEY
EOF")"
  assert_deny
}

@test "denies echo append into .env.example from Bash" {
  run "$HOOK" <<< "$(make_bash "echo 'PRIVATE_KEY=$HEXKEY' >> .env.example")"
  assert_deny
}

@test "allows the schema entry with an empty value" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "PRIVATE_KEY=
MNEMONIC=")"
  assert_allow
}

@test "allows placeholder values" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "PRIVATE_KEY=<your-private-key>
SEED_PHRASE=\"your twelve words here\"
PK=0x...
DEPLOYER_KEY=changeme
WALLET_KEY=\${WALLET_KEY}")"
  assert_allow
}

@test "allows rotatable secrets with real-looking values" {
  run "$HOOK" <<< "$(make_write "/p/.env.example" "API_KEY=$B58
PUBLIC_KEY=$HEXKEY
DATABASE_URL=postgres://u:p@h/db")"
  assert_allow
}

@test "ignores files that are not env templates" {
  run "$HOOK" <<< "$(make_write "/p/.env" "PRIVATE_KEY=$HEXKEY")"
  assert_allow
  run "$HOOK" <<< "$(make_write "/p/config.ts" "PRIVATE_KEY=$HEXKEY")"
  assert_allow
}

@test "ignores Bash commands that do not touch a template" {
  run "$HOOK" <<< "$(make_bash "echo PRIVATE_KEY=$HEXKEY > notes.txt")"
  assert_allow
}

@test "ignores a Bash command that only reads the template" {
  run "$HOOK" <<< "$(make_bash "cat .env.example")"
  assert_allow
}
