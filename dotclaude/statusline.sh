#!/bin/bash
# Claude Code status line: git branch+status, context remaining, model
set -euo pipefail

input=$(cat)

# -- Extract fields --
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# -- Colors --
green=$'\e[92m'
yellow=$'\e[33m'
red=$'\e[31m'
dim=$'\e[2m'
reset=$'\e[0m'

# -- Git branch + status --
git_part=""
cd "$cwd" 2>/dev/null || exit 0
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    short=$(git --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    branch="${short:-detached}"
  fi

  porcelain=$(git --no-optional-locks status --porcelain 2>/dev/null)
  staged=0 unstaged=0 untracked=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    x="${line:0:1}"
    y="${line:1:1}"
    [ "$x" = "?" ] && ((untracked++)) && continue
    [ "$x" != " " ] && ((staged++))
    [ "$y" != " " ] && ((unstaged++))
  done <<< "$porcelain"

  dirty=""
  [ $((staged + unstaged + untracked)) -gt 0 ] && dirty="*"

  file_counts=""
  [ "$staged" -gt 0 ] && file_counts+=" +${staged}"
  [ "$unstaged" -gt 0 ] && file_counts+=" ~${unstaged}"
  [ "$untracked" -gt 0 ] && file_counts+=" ?${untracked}"

  arrows=""
  if git --no-optional-locks rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead=$(git --no-optional-locks rev-list --count '@{u}..HEAD' 2>/dev/null)
    behind=$(git --no-optional-locks rev-list --count 'HEAD..@{u}' 2>/dev/null)
    [ "$ahead" -gt 0 ] 2>/dev/null && arrows+=" ↑${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && arrows+=" ↓${behind}"
  fi

  if [ -n "$dirty" ]; then
    git_part="${yellow}${branch}${dirty}${file_counts}${arrows}${reset}"
  else
    git_part="${green}${branch}${arrows}${reset}"
  fi
fi

# -- Context remaining --
remaining=$((100 - ${used_pct:-0}))
if [ "$remaining" -gt 50 ]; then
  ctx_part="${green}${remaining}%${reset} context"
elif [ "$remaining" -gt 20 ]; then
  ctx_part="${yellow}${remaining}%${reset} context"
else
  ctx_part="${red}${remaining}%${reset} context"
fi

# -- Rate limits --
rate_part=""
if [ -n "$rate_5h" ]; then
  r5=${rate_5h%.*}
  if [ "$r5" -gt 80 ] 2>/dev/null; then
    rate_part="${red}${r5}%${reset}"
  elif [ "$r5" -gt 50 ] 2>/dev/null; then
    rate_part="${yellow}${r5}%${reset}"
  else
    rate_part="${green}${r5}%${reset}"
  fi
  rate_part="${rate_part} 5h"
  if [ -n "$rate_7d" ]; then
    r7=${rate_7d%.*}
    if [ "$r7" -gt 80 ] 2>/dev/null; then
      rate_part+=" ${red}${r7}%${reset}"
    elif [ "$r7" -gt 50 ] 2>/dev/null; then
      rate_part+=" ${yellow}${r7}%${reset}"
    else
      rate_part+=" ${green}${r7}%${reset}"
    fi
    rate_part+=" 7d"
  fi
fi

# -- Model --
model_part=""
if [ -n "$model" ]; then
  model_part="${model}"
fi

# -- Assemble --
sections=()
[ -n "$git_part" ] && sections+=("$git_part")
[ -n "$ctx_part" ] && sections+=("$ctx_part")
[ -n "$rate_part" ] && sections+=("$rate_part")
[ -n "$model_part" ] && sections+=("$model_part")

out=""
for i in "${!sections[@]}"; do
  [ "$i" -gt 0 ] && out+=" ${dim}|${reset} "
  out+="${sections[$i]}"
done

printf '%s' "$out"
