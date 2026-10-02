#!/usr/bin/env bats

# Runs install.sh from a throwaway copy of the repo's tracked files against a
# throwaway HOME, with --skip-brew --skip-macos. Nothing outside the bats temp
# dirs is touched: the copy absorbs install.sh's git config and tmp/ writes,
# TMPDIR covers mktemp, and HOMEBREW_PREFIX covers the dnsmasq/caddy paths.
# mise is a stub that logs its args; bun/bunx stubs sit in a shims dir that is
# only on PATH after `mise activate`, like a fresh machine.
# Not covered: the Homebrew branch (needs a fresh Mac).

setup_file() {
  export REPO="$BATS_FILE_TMPDIR/repo"
  src="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  mkdir -p "$REPO"
  git -C "$src" ls-files -z | rsync -a --from0 --files-from=- "$src/" "$REPO/"
  git -C "$REPO" init -q
}

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  export HOMEBREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  export LOG="$BATS_TEST_TMPDIR/calls.log"
  stubs="$BATS_TEST_TMPDIR/stubs"
  shims="$BATS_TEST_TMPDIR/shims"
  mkdir -p "$HOME" "$TMPDIR" "$stubs" "$shims"
  cat > "$stubs/mise" <<EOF
#!/bin/bash
echo "mise \$*" >> "\$LOG"
[ "\$1" = activate ] && echo 'export PATH="$shims:\$PATH"'
exit 0
EOF
  for cmd in bun bunx; do
    printf '#!/bin/bash\necho "%s $*" >> "$LOG"\n' "$cmd" > "$shims/$cmd"
  done
  chmod +x "$stubs/mise" "$shims"/*
  export PATH="$stubs:/usr/bin:/bin"
}

install() {
  run bash "$REPO/install.sh" --skip-brew --skip-macos <<< "y"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "exits 0 on a clean home" {
  install
}

@test "links every entry in the files array to an existing source" {
  install
  files=$(sed -n '/^files=(/,/^)/p' "$REPO/install.sh" | sed '1d;$d' | tr -d ' ')
  [ -n "$files" ]
  for f in $files; do
    [ "$(readlink "$HOME/$f")" = "$REPO/$f" ] || { echo "not linked: $f"; false; }
    [ -e "$HOME/$f" ] || { echo "dangling: $f"; false; }
  done
}

@test "links each skill and the shared hooks for both agents" {
  install
  for dir in "$REPO"/dotagents/skills/*/; do
    name=$(basename "$dir")
    [ "$(readlink "$HOME/.claude/skills/$name")" = "$dir" ] || { echo "claude skill: $name"; false; }
    [ "$(readlink "$HOME/.agents/skills/$name")" = "$dir" ] || { echo "agents skill: $name"; false; }
  done
  [ "$(readlink "$HOME/.claude/hooks")" = "$REPO/dotagents/hooks" ]
  [ "$(readlink "$HOME/.codex/hooks")" = "$REPO/dotagents/hooks" ]
}

@test "bun steps run only after mise install and activation" {
  install
  mise_line=$(grep -n '^mise activate' "$LOG" | head -1 | cut -d: -f1)
  bun_line=$(grep -nE '^bunx? ' "$LOG" | head -1 | cut -d: -f1)
  grep -q '^mise install' "$LOG"
  [ -n "$mise_line" ] && [ -n "$bun_line" ]
  [ "$mise_line" -lt "$bun_line" ]
}

@test "links dnsmasq config under HOMEBREW_PREFIX" {
  mkdir -p "$HOMEBREW_PREFIX/etc/dnsmasq.d"
  install
  [ "$(readlink "$HOMEBREW_PREFIX/etc/dnsmasq.d/test.conf")" = "$REPO/dnsmasq/test.conf" ]
}

@test "rerun is safe" {
  install
  install
}

@test "rerun does not nest a directory backup inside an existing .bak" {
  skip "known bug: mv X X.bak nests X inside an existing X.bak directory"
  mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/hooks.bak"
  install
  [ ! -e "$HOME/.claude/hooks.bak/hooks" ]
}
