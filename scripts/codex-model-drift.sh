#!/usr/bin/env bash
# List pinned Codex model slugs older than the newest slug of the same tier
# (astra, sol, terra) in Codex's model catalog. Exits 1 when any is stale.
# Tiers have no versionless alias, so a pin goes stale silently when a new
# model ships. Checks the tracked copies and the live ones Codex reads
# (install.sh copies them instead of symlinking).
set -euo pipefail

cache="$HOME/.codex/models_cache.json"
root="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$cache" ] || { echo "missing $cache" >&2; exit 2; }

stale=0
while IFS= read -r hit; do
  file="${hit%%:*}"
  slug="$(sed -E 's/.*"([^"]+)".*/\1/' <<<"$hit")"
  tier="${slug##*-}"
  latest="$(jq -r --arg t "$tier" '[.models[] | select(.slug | test("^gpt-[0-9.]+-" + $t + "$"))] | sort_by(.priority)[0].slug // empty' "$cache")"
  if [ -n "$latest" ] && [ "$slug" != "$latest" ]; then
    echo "$file: $slug -> $latest"
    stale=1
  fi
done < <(rg --no-heading --no-line-number --with-filename '^model = "gpt-' \
  "$root/dotcodex" "$HOME/.codex/config.toml" "$HOME/.codex/agents" -g '*.toml' 2>/dev/null)

exit "$stale"
