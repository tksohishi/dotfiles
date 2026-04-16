---
name: "update"
description: "Update Homebrew packages, mise tools, Claude Code, and check Mac App Store updates"
---

Use this skill when the user asks to run `/update`.

Run the following update commands in order:

1. `brew update` to refresh the package index
2. `brew upgrade --formula` to upgrade all formulae
3. `mise upgrade` to upgrade all mise-managed tools
4. `claude update` to update Claude Code itself
5. `mas outdated` to check for Mac App Store updates

Run steps 1 through 5 directly. If step 5 shows available updates, tell the user to run `mas upgrade` themselves because it requires a password.

After `brew upgrade --formula`, run `agent-browser install` to update its browser binaries.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded, but only packages listed in the Brewfile. Skip transitive dependencies. For each upgraded package, briefly note notable changes if visible from the upgrade output.

For any Brewfile package with a major version bump, fetch its GitHub release notes and summarize breaking changes, new features, and deprecations.

If `claude update` upgraded Claude Code, fetch the changelog from `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md` and summarize significant changes between the prior and new version. Focus on new features, breaking changes, settings or hooks schema changes, and notable bug fixes. Skip trivial entries.

After upgrades, review the `brew update` output for `==> New Formulae` and `==> New Casks`. Surface only additions that look relevant to this setup, such as developer tools, terminal utilities, or productivity apps. Keep it short.
