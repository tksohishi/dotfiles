#!/bin/bash
# Merge dotcodex/config.toml -> ~/.codex/config.toml
# Preserves local [projects.*] sections from the destination.

set -euo pipefail

src="${BASH_SOURCE[0]%/*}/../dotcodex/config.toml"
dst="$HOME/.codex/config.toml"
tmp="$(mktemp)"

cp "$src" "$tmp"

if [ -f "$dst" ]; then
    projects="$(awk '
        BEGIN { p = 0 }
        /^\[projects\./ { p = 1; print; next }
        /^\[/ { p = 0 }
        { if (p) print }
    ' "$dst")"
    if [ -n "$projects" ]; then
        printf '\n%s\n' "$projects" >> "$tmp"
    fi
fi

if [ -f "$dst" ] && diff -q "$tmp" "$dst" >/dev/null 2>&1; then
    echo "Already up to date"
else
    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
        cp "$dst" "${dst}.bak"
        echo "Backed up ~/.codex/config.toml"
    fi
    cp "$tmp" "$dst"
    echo "Merged dotcodex/config.toml -> ~/.codex/config.toml"
fi

rm -f "$tmp"
