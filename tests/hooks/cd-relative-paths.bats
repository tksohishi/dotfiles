#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/cd-relative-paths.sh"

bash_input() {
  jq -n --arg cmd "$1" '{tool_input: {command: $cmd}}'
}

@test "denies the triggering shape: cd && rg with relative paths" {
  run "$HOOK" <<< "$(bash_input "cd ~/Work/drift && rg -n -i 'pattern' AGENTS.md src/domain/types.ts | head -30; rg -o 'pattern' src | sort -u; cd ~/Work/degen")"
  [ "$status" -eq 0 ]
  [[ "$output" == *deny* ]]
  [[ "$output" == *"rg AGENTS.md"* ]]
}

@test "denies cd ; cat relative" {
  run "$HOOK" <<< "$(bash_input 'cd /tmp/x; cat config.toml')"
  [[ "$output" == *deny* ]]
}

@test "denies cd && ls relative dir" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && ls src/')"
  [[ "$output" == *deny* ]]
}

@test "denies cd && find relative root" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && find . -name x')"
  [[ "$output" == *deny* ]]
}

@test "denies cd && rg -g glob with relative path after value flag" {
  run "$HOOK" <<< "$(bash_input "cd ~/proj && rg -g '*.ts' foo src")"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"rg src"* ]]
}

@test "allows rg with absolute path and no cd" {
  run "$HOOK" <<< "$(bash_input 'rg pattern ~/Work/drift/AGENTS.md')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows git -C" {
  run "$HOOK" <<< "$(bash_input 'git -C ~/Work/drift status --short')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows cd alone" {
  run "$HOOK" <<< "$(bash_input 'cd ~/Work/drift')"
  [ -z "$output" ]
}

@test "allows cd && absolute paths" {
  run "$HOOK" <<< "$(bash_input "cd ~/proj && rg -n 'x' /Users/me/proj/AGENTS.md; cat ~/proj/README.md")"
  [ -z "$output" ]
}

@test "allows cd && git (git is not a file tool)" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && git status --short')"
  [ -z "$output" ]
}

@test "allows cd && head with only a count flag" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && make 2>&1 | head -30')"
  [ -z "$output" ]
}

@test "allows cd && rg pattern with no path argument" {
  run "$HOOK" <<< "$(bash_input "cd ~/proj && rg -n 'pattern'")"
  [ -z "$output" ]
}

@test "allows file tool with relative path BEFORE the cd" {
  run "$HOOK" <<< "$(bash_input 'cat config.toml && cd ~/proj')"
  [ -z "$output" ]
}

@test "allows sed -n script with absolute file after cd" {
  run "$HOOK" <<< "$(bash_input "cd ~/proj && sed -n '1,5p' /abs/file")"
  [ -z "$output" ]
}

@test "allows in-tree cd (monorepo package) with relative paths" {
  run "$HOOK" <<< "$(bash_input "cd packages/api && rg -n 'x' src/index.ts; ls src/")"
  [ -z "$output" ]
}

@test "allows in-tree cd with ./ prefix" {
  run "$HOOK" <<< "$(bash_input "cd ./apps/web && cat package.json")"
  [ -z "$output" ]
}

@test "denies cd .. with relative path" {
  run "$HOOK" <<< "$(bash_input 'cd ../other && cat README.md')"
  [[ "$output" == *deny* ]]
}

@test "denies cd \$VAR with relative path" {
  run "$HOOK" <<< "$(bash_input 'cd "$DIR" && ls src')"
  [[ "$output" == *deny* ]]
}

@test "denies bare cd (home) with relative path" {
  run "$HOOK" <<< "$(bash_input 'cd && cat .zshrc')"
  [[ "$output" == *deny* ]]
}

@test "allows redirect tokens after cd" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && rg pattern /abs/src 2>/dev/null > /abs/out; ls /abs &>/dev/null')"
  [ -z "$output" ]
}

@test "allows heredoc after cd" {
  run "$HOOK" <<< "$(bash_input $'cd ~/proj && cat <<\'EOF\' | pbcopy\nhi\nEOF')"
  [ -z "$output" ]
}

@test "still denies relative path alongside a redirect" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && rg pattern src 2>/dev/null')"
  [[ "$output" == *"rg src"* ]]
}

@test "denies sed -n script with relative file" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && sed -n '1,5p' file.txt")"
  [[ "$output" == *"sed file.txt"* ]]
}

@test "denies cat -n relative file" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && cat -n file.txt')"
  [[ "$output" == *"cat file.txt"* ]]
}

@test "denies tail -f relative file" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && tail -f app.log')"
  [[ "$output" == *"tail app.log"* ]]
}

@test "denies ls -t relative dir" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && ls -t src')"
  [[ "$output" == *"ls src"* ]]
}

@test "denies rg -e pattern with relative path" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg -e pat src')"
  [[ "$output" == *"rg src"* ]]
}

@test "denies sed -e script with relative file" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && sed -e 's/a/b/' file.txt")"
  [[ "$output" == *"sed file.txt"* ]]
}

@test "allows fd -e ext -t f pattern with absolute root" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && fd -e ts -t f pat /abs')"
  [ -z "$output" ]
}

@test "denies fd pattern with relative root" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && fd -e ts pat src')"
  [[ "$output" == *"fd src"* ]]
}

@test "allows head -n 30 with absolute file" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && head -n 30 /abs/file')"
  [ -z "$output" ]
}

@test "allows empty command" {
  run "$HOOK" <<< '{"tool_input": {}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies grep with | inside a quoted pattern (pipe must not split the stage)" {
  run "$HOOK" <<< "$(bash_input "cd /private/tmp/claude-501/x/scratchpad && jq -r '\"\\(.date)|\\(.sender)\"' kudasai.jsonl > flat.txt && grep -inE 'pons|cashcat|RH' flat.txt | head -60")"
  [[ "$output" == *deny* ]]
  [[ "$output" == *"grep flat.txt"* ]]
}

@test "denies sed script containing ; with relative file" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && sed -n 's/a/b/;p' file.txt")"
  [[ "$output" == *"sed file.txt"* ]]
}

@test "allows 2>&1 and spaced redirect targets after cd" {
  run "$HOOK" <<< "$(bash_input 'cd ~/proj && cat /abs/file 2>&1 > out.txt; ls /abs >> log.txt')"
  [ -z "$output" ]
}

@test "denies relative path on a newline after cd" {
  run "$HOOK" <<< "$(bash_input $'cd ~/proj\ncat README.md')"
  [[ "$output" == *"cat README.md"* ]]
}

@test "allows && inside quotes after cd" {
  run "$HOOK" <<< "$(bash_input "cd ~/proj && rg 'a && b' /abs/file")"
  [ -z "$output" ]
}

@test "denies relative path inside a subshell after cd" {
  run "$HOOK" <<< "$(bash_input '(cd ~/proj && cat README.md)')"
  [[ "$output" == *"cat README.md"* ]]
}

@test "skips heredoc bodies (data, not commands)" {
  run "$HOOK" <<< "$(bash_input $'cd ~/x && python3 - <<\'EOF\'\nprint("a" | "b")\ncat f\nEOF\nls /abs')"
  [ -z "$output" ]
}

@test "heredoc with unbalanced quote in body does not hide a later read" {
  run "$HOOK" <<< "$(bash_input $'cd ~/x && cat <<EOF > out.txt\nit\'s\nEOF\ncat f')"
  [[ "$output" == *"cat f"* ]]
}

@test "allows heredoc redirect target after cd" {
  run "$HOOK" <<< "$(bash_input $'cd ~/x && cat > script.sh <<\'EOF\'\necho hi\nEOF')"
  [ -z "$output" ]
}

@test "ignores comments" {
  run "$HOOK" <<< "$(bash_input $'cd ~/x; # note && cat f\nls /abs')"
  [ -z "$output" ]
}

@test "backslash-newline continuation is whitespace" {
  run "$HOOK" <<< "$(bash_input $'cd ~/x && rg -n pat \\\n  /abs')"
  [ -z "$output" ]
  run "$HOOK" <<< "$(bash_input $'cd ~/x && rg -n pat \\\n  src')"
  [[ "$output" == *"rg src"* ]]
}

@test "denies inside a brace group" {
  run "$HOOK" <<< "$(bash_input '{ cd ~/x; cat f; }')"
  [[ "$output" == *"cat f"* ]]
}

@test "keeps \${VAR} and brace expansion as one word" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && cat ${HOME}/file; ls ${d}/x')"
  [[ "$output" == *'ls ${d}/x'* ]]
}

@test "denies through time/sudo/! wrappers and prefix redirects" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && time cat f')"
  [[ "$output" == *"cat f"* ]]
  run "$HOOK" <<< "$(bash_input 'cd ~/x && 2>/dev/null cat f')"
  [[ "$output" == *"cat f"* ]]
  run "$HOOK" <<< "$(bash_input 'builtin cd ~/x && ! cat f')"
  [[ "$output" == *"cat f"* ]]
}

@test "denies --regexp=PAT with relative path" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg --regexp=PAT src')"
  [[ "$output" == *"rg src"* ]]
}

@test "denies relative pattern file (-f) and relative input redirect" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg -f patterns /abs')"
  [[ "$output" == *"rg patterns"* ]]
  run "$HOOK" <<< "$(bash_input 'cd ~/x && cat < rel.txt')"
  [[ "$output" == *"cat <rel.txt"* ]]
  run "$HOOK" <<< "$(bash_input 'cd ~/x && cat < /abs/rel.txt')"
  [ -z "$output" ]
}

@test "quoted pattern starting with < is not a redirect" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && rg '<title>[^<]*' /abs/f")"
  [ -z "$output" ]
  run "$HOOK" <<< "$(bash_input "cd ~/x && rg '<title>[^<]*' f")"
  [[ "$output" == *"rg f"* ]]
}

@test "allows find expression operands (-name, -exec grep {} +)" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && find /abs -name '*.ts' -exec grep -l pat {} +")"
  [ -z "$output" ]
}

@test "allows BSD sed -i '' with absolute file" {
  run "$HOOK" <<< "$(bash_input "cd ~/x && sed -i '' 's/a/b/' /abs/file")"
  [ -z "$output" ]
}

@test "nested quotes inside \$(...) do not flip quote parity" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg "$(rg -l foo "/abs")" /abs; ls /abs')"
  [ -z "$output" ]
  run "$HOOK" <<< "$(bash_input 'cd ~/x && echo "$(cat "f")" && cat g')"
  [[ "$output" == *"cat g"* ]]
}

@test "top-level \$(...) is inspected, without a stray \$ token" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg foo $(rg -l foo --glob "*.py" /abs | head -1)')"
  [ -z "$output" ]
  run "$HOOK" <<< "$(bash_input 'cd ~/x && rg foo $(rg -l foo src)')"
  [[ "$output" == *"rg src"* ]]
}

@test "allows here-string and ls with only flags" {
  run "$HOOK" <<< "$(bash_input 'cd ~/x && cat <<< "$x" | head; ls -la')"
  [ -z "$output" ]
}
