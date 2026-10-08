#!/usr/bin/env zsh
# Daily snapshot of Claude Code auto-memory into a git repo outside ~/.claude,
# so `git log -p` shows what any session or auto-dream changed and any file
# can be restored. Installed as a LaunchAgent by setup-memory-backup.sh.
set -euo pipefail

DEST="$HOME/Backups/claude-memory"
exec >>"$HOME/Library/Logs/claude-memory-backup.log" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') start ==="

mkdir -p "$DEST"
[[ -d "$DEST/.git" ]] || git -C "$DEST" init -q

for src in "$HOME"/.claude/projects/*/memory(N/); do
  project=${src:h:t}
  mkdir -p "$DEST/$project"
  rsync -a --delete "$src/" "$DEST/$project/"
done

git -C "$DEST" add -A
if git -C "$DEST" diff --cached --quiet; then
  echo "no changes"
else
  git -C "$DEST" commit -q -m "Snapshot $(date +%F)"
  git -C "$DEST" log --oneline -1 --stat | tail -1
fi
echo "=== $(date '+%Y-%m-%d %H:%M:%S') end ==="
