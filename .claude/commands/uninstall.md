---
description: Uninstall an app via Homebrew and remove it from the Brewfile
argument-hint: <app-name>
allowed-tools: [Bash, Read, Edit, Write]
---

The user wants to uninstall: $ARGUMENTS

Follow these steps:

1. Check if the app is installed and determine its source:
   - Run `brew list --formula | grep $ARGUMENTS` and `brew list --cask | grep $ARGUMENTS`
   - Run `mas list | grep -i $ARGUMENTS`
   - If not found in any source, inform the user and stop

2. Uninstall the app:
   - For formulae: `brew uninstall <name>`
   - For casks: `brew uninstall --cask <name>`
   - For Mac App Store: `mas uninstall <id>`

3. Remove the app from the Brewfile at `~/.dotfiles/Brewfile`:
   - Read the Brewfile first
   - Remove the matching `brew "<name>"`, `cask "<name>"`, or `mas "<name>", id: <id>` line
   - Keep the existing formatting

4. Commit and push:
   - `git add Brewfile`
   - Commit with message like "Remove <name> from Brewfile"
   - `git push origin main`
