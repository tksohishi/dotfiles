---
description: Update all Homebrew packages, casks, and Mac App Store apps
allowed-tools: [Bash]
---

Run the following update commands in order:

1. `brew update` — refresh package index
2. `brew upgrade --formula` — upgrade all formulae (formulae only; cask apps auto-update themselves)
3. `mise upgrade` — upgrade all mise-managed tools
4. `claude update` — update Claude Code itself
5. `mas outdated` — check for Mac App Store updates

Run steps 1-5 directly. If step 5 shows available updates, tell the user to run `mas upgrade` themselves (it requires a password).

After `brew upgrade --formula`, run `agent-browser install` to update its browser binaries.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded, but only packages listed in the Brewfile (skip transitive dependencies). For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) if visible from the upgrade output. For any Brewfile package with a **major version bump**, fetch its GitHub release notes (e.g. `https://github.com/<org>/<repo>/releases/tag/v<version>`) and summarize breaking changes, new features, and deprecations.

After upgrades, check for interesting new formulae and casks. The `brew update` output from step 1 lists new additions under "==> New Formulae" and "==> New Casks". Review those and highlight any that look relevant to the user's setup (developer tools, terminal utilities, productivity apps, etc.). If any look worth checking out, suggest them briefly with a one-line description. Don't overwhelm; only surface genuinely interesting additions.
