---
name: update-apps
description: Update all Homebrew packages, casks, and Mac App Store apps
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

After `agent-browser install`, prune stale browser caches across the three locations below. Each tool accumulates versions on upgrade rather than replacing them, and none have built-in cleanup.

For each cache root, list its versioned subdirectories, then delete all but the newest of each group. Group by the directory name prefix; rank by the version segment (numeric/semver where present, mtime otherwise).

- `~/.agent-browser/browsers/chrome-<semver>/` — keep highest semver
- `~/.cache/puppeteer/chrome/<arch>-<semver>/` and `~/.cache/puppeteer/chrome-headless-shell/<arch>-<semver>/` — keep highest semver per arch prefix (`mac_arm`, `mac`, `linux`, ...)
- `~/Library/Caches/ms-playwright/chromium-<n>/`, `chromium_headless_shell-<n>/`, `firefox-<n>/` — keep highest-numbered of each prefix
- `~/Library/Caches/ms-playwright/mcp-chrome-<sha>/`, `mcp-firefox-<sha>/`, `mcp-webkit-<sha>/` — keep most recently modified per browser

Don't touch `ffmpeg-*`, `mcp-chrome-profile`, or unsuffixed entries like `mcp-chrome`. Report total bytes reclaimed across all locations.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

Report what was upgraded, but only packages listed in the Brewfile. Transitive dependencies should be omitted entirely unless they had a **major version bump**, in which case surface them as informational. Also report any Brewfile entries that were newly installed because they were missing locally. For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) if visible from the upgrade output. For any Brewfile package with a **major version bump**, fetch its GitHub release notes (e.g. `https://github.com/<org>/<repo>/releases/tag/v<version>`) and summarize breaking changes, new features, and deprecations.

Always fetch the Claude Code changelog from `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md` and summarize the current installed version's entry plus any newer-than-last-run entries you can find. Claude Code auto-updates between sessions, so checking only when `claude update` upgrades misses the case where the version moved silently — this step fires every run regardless of what `claude update` reports. Cover new features, breaking changes, settings/hooks schema changes, and notable bug fixes. Skip trivial entries (typo fixes, internal refactors).

After upgrades, check for interesting new formulae and casks. The `brew update` output from step 1 lists new additions under "==> New Formulae" and "==> New Casks". Review those and highlight any that look relevant to the user's setup (developer tools, terminal utilities, productivity apps, etc.). If any look worth checking out, suggest them briefly with a one-line description. Don't overwhelm; only surface genuinely interesting additions.
