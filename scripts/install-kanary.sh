#!/bin/bash
set -euo pipefail

url="https://kanary.download/ja/download"
tmp_dir="$(mktemp -d)"
zip_path="$tmp_dir/Kanary.zip"
app_path="$tmp_dir/Kanary.app"
target="/Applications/Kanary.app"

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

if [ "$(uname -m)" != "arm64" ]; then
    echo "Kanary requires Apple Silicon."
    exit 1
fi

macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$macos_major" -lt 14 ]; then
    echo "Kanary requires macOS 14 Sonoma or later."
    exit 1
fi

echo "Downloading Kanary..."
curl -fsSL "$url" -o "$zip_path"

echo "Unzipping Kanary..."
ditto -x -k "$zip_path" "$tmp_dir"

if [ ! -d "$app_path" ]; then
    echo "Kanary.app was not found in the downloaded archive."
    exit 1
fi

if [ -d "$target" ]; then
    echo "Replacing existing Kanary.app..."
    rm -rf "$target"
fi

echo "Installing Kanary.app to /Applications..."
ditto "$app_path" "$target"
xattr -r -w com.apple.quarantine "0081;00000000;Codex;https://kanary.download/ja/download" "$target"

echo "Installed Kanary.app."
echo "Open it once from /Applications and grant the requested keyboard/accessibility permissions."
