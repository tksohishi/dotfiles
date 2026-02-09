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

4. Tell the user the command to run to uninstall the app:
   - For formulae: `brew uninstall <name>`
   - For casks: `brew uninstall --cask <name>`
   - For Mac App Store: `mas uninstall <id>`
   - Do NOT run the uninstall command yourself, as it may require sudo
