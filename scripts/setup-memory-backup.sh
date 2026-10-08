#!/usr/bin/env zsh
# Render memory-backup.plist.template with this shell's PATH/HOME and load it.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.tksohishi.claude-memory-backup.daily"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
TEMPLATE="$REPO_DIR/scripts/memory-backup.plist.template"

[[ -x "$REPO_DIR/scripts/memory-backup.sh" ]] || { echo "wrapper not executable" >&2; exit 1; }

escape() { printf '%s' "$1" | sed -e 's/[\&|]/\\&/g'; }

rm -f "$PLIST_DST"
sed \
  -e "s|__REPO_DIR__|$(escape "$REPO_DIR")|g" \
  -e "s|__PATH__|$(escape "$PATH")|g" \
  -e "s|__HOME__|$(escape "$HOME")|g" \
  "$TEMPLATE" > "$PLIST_DST"

launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "Loaded $LABEL"
