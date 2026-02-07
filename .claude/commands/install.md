---
description: Install an app via Homebrew and add it to the Brewfile
argument-hint: <app-name>
allowed-tools: [Bash, Read, Edit, Write]
---

The user wants to install: $ARGUMENTS

Follow these steps:

1. Determine the install source (formula, cask, or Mac App Store):
   - Run `brew search $ARGUMENTS` to find matching formulae and casks
   - Run `mas search $ARGUMENTS` to check the Mac App Store
   - If matches exist in multiple sources, show the options and ask the user which one to install

2. Install the app:
   - For formulae: `brew install <name>`
   - For casks: `brew install --cask <name>`
   - For Mac App Store: `mas install <id>`

3. Add the app to the Brewfile at `~/.dotfiles/Brewfile`:
   - Read the Brewfile first
   - Add the appropriate line in the correct section, maintaining alphabetical order within each section:
     - Formula: `brew "<name>"` (in the brew section)
     - Cask: `cask "<name>"` (in the cask section)
     - Mac App Store: `mas "<name>", id: <id>` (in the mas section)
   - Keep the existing formatting and ordering

4. Commit and push:
   - `git add Brewfile`
   - Commit with message like "Add <name> to Brewfile"
   - `git push origin main`
