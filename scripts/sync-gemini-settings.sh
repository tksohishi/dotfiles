#!/bin/bash
# Merge dotgemini/settings.json -> ~/.gemini/settings.json
# Overwrites the "tools" and "model" keys from source; preserves everything else in destination.

set -euo pipefail

src="${BASH_SOURCE[0]%/*}/../dotgemini/settings.json"
dst="$HOME/.gemini/settings.json"
tmp="$(mktemp)"

if [ ! -f "$src" ]; then
    echo "Source not found: $src"
    exit 1
fi

if [ -f "$dst" ]; then
    jq -s '.[0] + {tools: (.[1].tools // {}), model: (.[1].model // .[0].model)}' "$dst" "$src" > "$tmp"
else
    cp "$src" "$tmp"
fi

if [ -f "$dst" ] && diff -q "$tmp" "$dst" >/dev/null 2>&1; then
    echo "Already up to date"
else
    mkdir -p "$(dirname "$dst")"
    cp "$tmp" "$dst"
    echo "Merged dotgemini/settings.json -> ~/.gemini/settings.json"
fi

rm -f "$tmp"
