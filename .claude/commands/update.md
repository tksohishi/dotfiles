---
description: Update all Homebrew packages, casks, and Mac App Store apps
allowed-tools: [Bash]
---

Run the following update commands in order:

1. `brew update` — refresh package index
2. `brew upgrade` — upgrade all formulae
3. `brew upgrade --cask` — upgrade all casks (some auto-update casks may be skipped)
4. `mas upgrade` — upgrade Mac App Store apps (may require sudo)

Run steps 1-3 directly. For step 4, tell the user the command to run since it may require sudo.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded.
