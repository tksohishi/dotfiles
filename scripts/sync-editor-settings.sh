#!/bin/bash
# Merge editors/settings.common.json into every installed VS Code-family
# editor's User/settings.json (VS Code, Cursor, Windsurf, Antigravity).
# Recursive merge: keys in the common file win, sibling keys inside the same
# object and everything else in the editor file are kept.
# A settings.json with JSONC comments or trailing commas is normalized to
# plain JSON on first merge.

set -euo pipefail

repo="${BASH_SOURCE[0]%/*}/.."
src="$repo/editors/settings.common.json"
tmp_dir="$repo/tmp"
tmp="$tmp_dir/sync-editor-settings.$$.json"
mkdir -p "$tmp_dir"
trap 'rm -f "$tmp"' EXIT

for app in Code Cursor Windsurf Antigravity; do
    user_dir="$HOME/Library/Application Support/$app/User"
    [ -d "$user_dir" ] || continue
    dst="$user_dir/settings.json"

    if [ -f "$dst" ]; then
        # Strip // line comments and trailing commas so jq can parse JSONC.
        perl -0pe 's#^\s*//.*$##mg; s#,(\s*[\]\}])#$1#g' "$dst" \
            | jq -s '.[0] * .[1]' - "$src" > "$tmp"
    else
        jq . "$src" > "$tmp"
    fi

    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
        echo "$app: settings.json up to date"
    else
        cp "$tmp" "$dst"
        echo "$app: merged editors/settings.common.json -> settings.json"
    fi
done
