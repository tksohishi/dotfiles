#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../../dotagents/hooks/one-change-per-call.sh"

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  git init -q "$R" && mkdir -p "$R/docs" && touch "$R/docs/review.log" "$R/c.json" && git -C "$R" add docs/review.log c.json
}

check() { run "$HOOK" <<< "$(jq -nc --arg c "$1" --arg d "$R" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')"; }
denied() { jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<< "$output"; }

@test "denies the chain that prompted it" {
  check 'echo "reviewed" >> docs/review.log && git add docs/review.log && git commit -m "Log review" -- docs/review.log && git push && git worktree remove --force ../wt'
  denied
  [[ "$output" == *"> docs/review.log"* && "$output" == *"git worktree remove"* ]]
}

@test "lets a commit and its push share a call" {
  check 'git commit -q -m "Fix the thing; and more && stuff" -- a.sh && git push -q && git log --oneline -1'
  [ -z "$output" ]
}

@test "passes one change with reads and tests beside it" {
  check 'cd app && bun test && tsc --noEmit && git commit -m "x" -- a.ts'
  [ -z "$output" ]
  check 'rg -n foo src | head && git status --short && jq -r .a f.json > tmp/out.json'
  [ -z "$output" ]
}

@test "counts rm, mv, sed -i, deploys and redirects" {
  check 'sed -i "" "s/a/b/" f.txt && mv f.txt g.txt'
  denied
  check 'scripts/aws.sh deploy && scripts/aws.sh start'
  denied
  check 'jq ".a = 1" c.json > c.json && rm b.json'
  denied
}

@test "does not count a redirect into scratch output or a new file" {
  check 'jq . a.json > tmp/a.json && jq . b.json > /abs/tmp/b.json && rg x > out.tsv && rm z.json'
  [ -z "$output" ]
}

@test "ignores separators and words inside quotes and heredoc bodies" {
  check $'git commit -F - -- a.sh <<\'EOF\'\nrm -rf x && git push && deploy\nEOF'
  [ -z "$output" ]
  check "jq '.x | select(.y > 3)' f.json && echo 'rm a; mv b c'"
  [ -z "$output" ]
}

@test "allows stderr to /dev/null and fd redirects" {
  check 'git push 2>/dev/null || git push --set-upstream origin main 2>&1'
  [ -z "$output" ]
}

@test "denies a long state-changing command, not counting the commit message" {
  long=$(printf 'a%.0s' {1..400})
  check "git commit -m \"$long\" -- a.sh"
  [ -z "$output" ]
  check "cp src/$long dst/"
  denied
  [[ "$output" == *"too long"* ]]
  check "rg -n '$long' src"
  [ -z "$output" ]
}
