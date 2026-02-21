---
description: Update all Homebrew packages, casks, and Mac App Store apps
allowed-tools: [Bash]
---

Run the following update commands in order:

1. `brew update` — refresh package index
2. `brew upgrade` — upgrade all formulae
3. `brew upgrade --cask --greedy` — upgrade all casks including ones that auto-update
4. `mise upgrade` — upgrade all mise-managed tools
5. `mas upgrade` — upgrade Mac App Store apps (may require sudo)

Run steps 1-4 directly. For step 5, tell the user the command to run since it may require sudo.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded. For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) if visible from the upgrade output.

After upgrades, check for interesting new formulae and casks. The `brew update` output from step 1 lists new additions under "==> New Formulae" and "==> New Casks". Review those and highlight any that look relevant to the user's setup (developer tools, terminal utilities, productivity apps, etc.). If any look worth checking out, suggest them briefly with a one-line description. Don't overwhelm; only surface genuinely interesting additions.
