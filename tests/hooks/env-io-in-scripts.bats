#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/env-io-in-scripts.sh"

bash_input() {
  jq -n --arg cmd "$1" --arg cwd "$2" '{cwd: $cwd, tool_input: {command: $cmd}}'
}

codex_input() {
  jq -n --arg cmd "$1" --arg cwd "$2" '{model: "gpt-5.6", cwd: $cwd, tool_input: {command: $cmd}}'
}

@test "asks on bun script that readFileSync's .env" {
  mkdir -p "$BATS_TEST_TMPDIR/scripts"
  cat > "$BATS_TEST_TMPDIR/scripts/x.ts" <<'EOF'
import { readFileSync } from "node:fs";
const raw = readFileSync(".env", "utf8");
EOF
  run "$HOOK" <<< "$(bash_input 'bun scripts/x.ts' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"scripts/x.ts"* ]]
  [[ "$output" == *"readFileSync"* ]]
}

@test "denies (not asks) under Codex" {
  mkdir -p "$BATS_TEST_TMPDIR/scripts"
  cat > "$BATS_TEST_TMPDIR/scripts/x.ts" <<'EOF'
const raw = readFileSync(".env", "utf8");
EOF
  run "$HOOK" <<< "$(codex_input 'bun scripts/x.ts' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"deny"'* ]]
  [[ "$output" != *'"ask"'* ]]
}

@test "asks when cd precedes the interpreter (absolute)" {
  mkdir -p "$BATS_TEST_TMPDIR/d"
  cat > "$BATS_TEST_TMPDIR/d/x.ts" <<'EOF'
await Bun.file(".env").text();
EOF
  run "$HOOK" <<< "$(bash_input "cd \"$BATS_TEST_TMPDIR/d\" && bun x.ts" "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"d/x.ts"* ]]
}

@test "asks when cd precedes the interpreter (relative to cwd)" {
  mkdir -p "$BATS_TEST_TMPDIR/d"
  cat > "$BATS_TEST_TMPDIR/d/x.ts" <<'EOF'
const raw = readFileSync(".env");
EOF
  run "$HOOK" <<< "$(bash_input 'cd d && bun x.ts' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"d/x.ts"* ]]
}

@test "scans every code file argument, not just the last" {
  cat > "$BATS_TEST_TMPDIR/loader.mjs" <<'EOF'
export function resolve(s, c, next) { return next(s, c); }
EOF
  cat > "$BATS_TEST_TMPDIR/x.js" <<'EOF'
const fs = require("fs");
const raw = fs.readFileSync(".env.production", "utf8");
EOF
  run "$HOOK" <<< "$(bash_input 'node --import loader.mjs x.js' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"x.js"* ]]
}

@test "asks on python open(.env)" {
  cat > "$BATS_TEST_TMPDIR/x.py" <<'EOF'
with open(".env") as fh:
    data = fh.read()
EOF
  run "$HOOK" <<< "$(bash_input 'python3 x.py' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"x.py"* ]]
}

@test "asks on pathlib read_text of .env.local" {
  cat > "$BATS_TEST_TMPDIR/y.py" <<'EOF'
from pathlib import Path
token = Path(".env.local").read_text()
EOF
  run "$HOOK" <<< "$(bash_input 'python3 y.py' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"y.py"* ]]
}

@test "asks on inline -e code" {
  run "$HOOK" <<< "$(bash_input 'node -e '"'"'require("fs").writeFileSync(".env", s)'"'"'' "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"Inline code"* ]]
}

@test "asks on heredoc fed to stdin" {
  cmd=$'node - <<\'EOF\'\nrequire("fs").readFileSync(".env")\nEOF'
  run "$HOOK" <<< "$(bash_input "$cmd" "$BATS_TEST_TMPDIR")"
  [[ "$output" == *'"ask"'* ]]
  [[ "$output" == *"Inline code"* ]]
}

@test "silent when inline source comes from a command substitution" {
  run "$HOOK" <<< "$(bash_input 'bun -e "$(cat f)"' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent when the script path holds a variable or a glob" {
  run "$HOOK" <<< "$(bash_input 'node --check "$S/burn.js" && bun scripts/*.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent when .env appears only in a comment and process.env" {
  cat > "$BATS_TEST_TMPDIR/ok.ts" <<'EOF'
// loads .env before anything else
const key = process.env.FOO;
const cfg = readFileSync("config.json", "utf8");
EOF
  run "$HOOK" <<< "$(bash_input 'bun ok.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on .env.example" {
  cat > "$BATS_TEST_TMPDIR/ok.ts" <<'EOF'
const schema = readFileSync(".env.example", "utf8");
EOF
  run "$HOOK" <<< "$(bash_input 'bun ok.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on I/O against other files" {
  cat > "$BATS_TEST_TMPDIR/ok.ts" <<'EOF'
const raw = readFileSync("package.json", "utf8");
writeFileSync("out.txt", raw);
EOF
  run "$HOOK" <<< "$(bash_input 'bun ok.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on bun test" {
  run "$HOOK" <<< "$(bash_input 'bun test' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on node --version" {
  run "$HOOK" <<< "$(bash_input 'node --version' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on vitest run" {
  run "$HOOK" <<< "$(bash_input 'vitest run' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on bun run build" {
  run "$HOOK" <<< "$(bash_input 'bun run build' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on non-interpreter commands" {
  run "$HOOK" <<< "$(bash_input 'cat README.md' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent when the script path does not exist" {
  run "$HOOK" <<< "$(bash_input 'bun missing.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent on --env-file with a clean script" {
  cat > "$BATS_TEST_TMPDIR/x.ts" <<'EOF'
console.log(process.env.TOKEN);
EOF
  run "$HOOK" <<< "$(bash_input 'bun --env-file=.env x.ts' "$BATS_TEST_TMPDIR")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
