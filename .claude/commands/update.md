---
description: Update all Homebrew packages, casks, and Mac App Store apps
allowed-tools: [Bash]
---

Run the following update commands in order:

1. `brew update` — refresh package index
2. `brew bundle install --no-upgrade` — install any missing Brewfile entries without upgrading already-present ones (upgrades are handled by step 3 for formulae, auto-update for casks, and `mas upgrade` manually for App Store apps)
3. `brew upgrade --formula` — upgrade all formulae (formulae only; cask apps auto-update themselves)
4. `mise upgrade` — upgrade all mise-managed tools
5. `claude update` — update Claude Code itself
6. `mas outdated` — check for Mac App Store updates

Run steps 1-6 directly. If step 6 shows available updates, tell the user to run `mas upgrade` themselves (it requires a password).

After `brew upgrade --formula`, run `agent-browser install` to update its browser binaries.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded, but only packages listed in the Brewfile (skip transitive dependencies). Also report any Brewfile entries that were newly installed because they were missing locally. For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) if visible from the upgrade output. For any Brewfile package with a **major version bump**, fetch its GitHub release notes (e.g. `https://github.com/<org>/<repo>/releases/tag/v<version>`) and summarize breaking changes, new features, and deprecations.

If `claude update` upgraded Claude Code (any version bump, not just major), fetch the changelog from `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md` and summarize significant changes between the prior and new version: new features, breaking changes, settings/hooks schema changes, and notable bug fixes. Skip trivial entries (typo fixes, internal refactors).

After upgrades, check for interesting new formulae and casks. The `brew update` output from step 1 lists new additions under "==> New Formulae" and "==> New Casks". Review those and highlight any that look relevant to the user's setup (developer tools, terminal utilities, productivity apps, etc.). If any look worth checking out, suggest them briefly with a one-line description. Don't overwhelm; only surface genuinely interesting additions.
