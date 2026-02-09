---
description: Audit installed apps against the Brewfile and suggest changes
allowed-tools: [Bash, Read]
---

Audit the current machine's installed packages against the Brewfile at `~/.dotfiles/Brewfile`.

Follow these steps:

1. Find untracked packages (installed but not in Brewfile):
   - Run `brew bundle cleanup` to list packages not in the Brewfile
   - Run `ls /Applications/` to find GUI apps not managed by Homebrew at all

2. Find missing packages (in Brewfile but not installed):
   - Run `brew bundle check --verbose` to list packages in the Brewfile that aren't installed
   - Cross-check against `ls /Applications/` and `mas list` since some may be installed outside Homebrew

3. Present a summary with two sections:

   **Untracked** (installed but not in Brewfile):
   - List each package with a brief description of what it is
   - Suggest whether to add it to the Brewfile or uninstall it

   **Missing** (in Brewfile but not installed):
   - Distinguish between truly missing apps and apps installed outside Homebrew
   - List each package
   - Ask if they should be installed or removed from the Brewfile

4. Wait for the user to decide what to do before making any changes.
