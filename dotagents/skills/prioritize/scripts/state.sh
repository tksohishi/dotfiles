#!/bin/sh
# Print each tmp/plans/ brief's frontmatter and the commit count on its `touches`
# paths since the brief's date, without ever printing a body.
set -eu
root=${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}

for f in "$root"/tmp/plans/[0-9][0-9][0-9][0-9]-*.md; do
  [ -e "$f" ] || continue
  echo "== ${f#"$root"/}"
  fm=$(sed -n '1{/^---$/!q;};2,/^---$/p' "$f" | sed '$d')
  if [ -z "$fm" ]; then
    echo "no-frontmatter"
    continue
  fi
  echo "$fm"
  # touches as a flow list `[a, b]` or a block list of `- a` lines
  touches=$(printf '%s\n' "$fm" | awk '
    /^touches:/ { sub(/^touches:[ ]*/, ""); sub(/#.*/, "")
                  if ($0 ~ /\[/) { gsub(/[][,]/, " "); print; exit } block = 1; next }
    block && /^[ ]+-/ { sub(/^[ ]+-[ ]*/, ""); sub(/#.*/, ""); print; next }
    block { exit }')
  if [ -z "$(printf '%s' "$touches" | tr -d ' \n')" ]; then
    echo "commits-since: n/a (no touches)"
    continue
  fi
  date=$(basename "$f" | cut -c1-10)
  # word splitting on $touches is intended: one path per word
  # shellcheck disable=SC2086
  n=$(git -C "$root" log --oneline --since="$date 00:00" -- $touches | wc -l | tr -d ' ')
  echo "commits-since: $n"
done
