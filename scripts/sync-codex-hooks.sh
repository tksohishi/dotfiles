#!/bin/bash
# Merge dotcodex/hooks.json -> ~/.codex/hooks.json.
# Preserves hooks owned by Otty or other local tools.

set -euo pipefail

repo="${BASH_SOURCE[0]%/*}/.."
src="$repo/dotcodex/hooks.json"
dst="$HOME/.codex/hooks.json"
tmp_dir="$repo/tmp"
tmp="$tmp_dir/sync-codex-hooks.$$.json"

mkdir -p "$HOME/.codex" "$tmp_dir"
trap 'rm -f "$tmp"' EXIT

inputs=("$src")
if [ -f "$dst" ]; then
    inputs+=("$dst")
fi

jq -s '
    .[0] as $src
    | (.[1] // {"hooks": {}}) as $dst
    | ($dst.hooks // {}
        | with_entries(.value |= map(select(._dotfiles != true)))) as $preserved
    | $dst
    | .hooks = reduce (($src.hooks // {}) | to_entries[]) as $entry
        ($preserved; .[$entry.key] = ((.[$entry.key] // []) + $entry.value))
' "${inputs[@]}" > "$tmp"

if [ -f "$dst" ] && diff -q "$tmp" "$dst" >/dev/null 2>&1; then
    echo "Skipped dotcodex/hooks.json (unchanged)"
else
    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
        cp "$dst" "${dst}.bak"
        echo "Backing up $dst to ${dst}.bak"
    fi
    cp "$tmp" "$dst"
    echo "Merged dotcodex/hooks.json -> ~/.codex/hooks.json"
fi
