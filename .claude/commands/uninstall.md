---
description: Uninstall an app via Homebrew and remove it from the Brewfile
argument-hint: <app-name>
allowed-tools: [Bash, Read, Edit, Write]
---

The user wants to uninstall: $ARGUMENTS

Follow these steps:

1. Check if the app is in the Brewfile and determine its source:
   - Read the Brewfile at `~/.dotfiles/Brewfile`
   - Also run `brew list --formula | grep $ARGUMENTS` and `brew list --cask | grep $ARGUMENTS`
   - Also run `mas list | grep -i $ARGUMENTS`
   - If not found in any source, inform the user and stop

2. Remove the app from the Brewfile at `~/.dotfiles/Brewfile`:
   - Remove the matching `brew "<name>"`, `cask "<name>"`, or `mas "<name>", id: <id>` line
   - Keep the existing formatting

3. Commit and push:
   - `git add Brewfile`
   - Commit with message like "Remove <name> from Brewfile"
   - `git push origin main`

4. For casks, capture the bundle ID and reset TCC permissions before uninstalling (tccutil requires the .app to still exist):
   - Get the .app name: `brew info --json=v2 --cask <name> | jq -r '.casks[0].artifacts[] | .app? // empty | .[0]'`
   - Read the bundle ID: `defaults read "/Applications/<AppName>.app/Contents/Info.plist" CFBundleIdentifier`
   - Run `tccutil reset All <bundle_id>` to remove all privacy permissions (Accessibility, Screen Recording, Input Monitoring, etc.)
   - If any command fails, skip TCC cleanup (app may already be removed)

5. Uninstall the app:
   - For formulae: run `brew uninstall <name>`
   - For casks: run `brew uninstall --cask <name>`. If it fails due to sudo/permission errors, tell the user to manually remove the listed files with `sudo rm -rf <paths>` then retry the brew uninstall
   - For Mac App Store: tell the user to run `mas uninstall <id>` (requires sudo)

6. Clean up allowlist rules:
   - Check `~/.dotfiles/dotclaude/settings.json` for any `Bash(<name> *)` or `Bash(<name> <subcommand> *)` rules related to the uninstalled tool
   - If found, remove them and inform the user
