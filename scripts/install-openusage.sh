#!/bin/bash
set -euo pipefail

latest_url="https://github.com/robinebers/openusage/releases/latest/download/latest.json"
tmp_dir="$(mktemp -d)"
latest_path="$tmp_dir/latest.json"
archive_path="$tmp_dir/OpenUsage.app.tar.gz"
app_path="$tmp_dir/OpenUsage.app"
target="/Applications/OpenUsage.app"

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

case "$(uname -m)" in
    arm64) platform="darwin-aarch64" ;;
    x86_64) platform="darwin-x86_64" ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

echo "Fetching latest OpenUsage release metadata..."
curl -fsSL "$latest_url" -o "$latest_path"

version="$(jq -r '.version' "$latest_path")"
url="$(jq -r --arg platform "$platform" '.platforms[$platform].url // empty' "$latest_path")"

if [ -z "$url" ]; then
    echo "No OpenUsage download found for $platform."
    exit 1
fi

echo "Downloading OpenUsage $version..."
curl -fsSL "$url" -o "$archive_path"

echo "Unpacking OpenUsage..."
tar -xzf "$archive_path" -C "$tmp_dir"

if [ ! -d "$app_path" ]; then
    echo "OpenUsage.app was not found in the downloaded archive."
    exit 1
fi

if [ -d "$target" ]; then
    echo "Replacing existing OpenUsage.app..."
    rm -rf "$target"
fi

echo "Installing OpenUsage.app to /Applications..."
ditto "$app_path" "$target"
xattr -r -w com.apple.quarantine "0081;00000000;Codex;https://github.com/robinebers/openusage/releases" "$target"

echo "Installed OpenUsage $version."
echo "Open it once from /Applications."
