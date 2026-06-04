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

After `agent-browser install`, prune stale browser caches across the two locations below. Each tool accumulates versions on upgrade rather than replacing them, and none have built-in cleanup.

For each cache root, list its versioned subdirectories, then delete all but the newest of each group. Group by the directory name prefix; rank by the version segment (numeric/semver where present, mtime otherwise).

- `~/.agent-browser/browsers/chrome-<semver>/` — keep highest semver
- `~/Library/Caches/ms-playwright/chromium-<n>/`, `chromium_headless_shell-<n>/`, `firefox-<n>/` — keep highest-numbered of each prefix
- `~/Library/Caches/ms-playwright/mcp-chrome-<sha>/`, `mcp-firefox-<sha>/`, `mcp-webkit-<sha>/` — keep most recently modified per browser

Don't touch `ffmpeg-*`, `mcp-chrome-profile`, or unsuffixed entries like `mcp-chrome`. Report total bytes reclaimed across all locations.

After upgrades complete, run `brew cleanup` to remove old versions and free disk space.

## What to report

Brewfile packages only. Transitive deps are omitted unless they had a **major version bump**, in which case surface them as informational. Also report Brewfile entries that were newly installed because they were missing locally. For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) visible from the upgrade output. For any Brewfile package with a major version bump, fetch its GitHub release notes (e.g. `https://github.com/<org>/<repo>/releases/tag/v<version>`) and summarize breaking changes, new features, and deprecations.

**Filter explicitly before reporting**: `brew upgrade --formula` upgrades transitive deps alongside Brewfile entries. Before listing in the Brewfile section, cross-check each name with `rg -nw '<name1>|<name2>|...' Brewfile` and drop any that don't appear. Easy to miss because the upgrade output looks identical for both. Past slip: deno appeared in the report as a Brewfile upgrade when it's actually a transitive dep of summarize and yt-dlp.

Always fetch the Claude Code changelog from `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md` and summarize the current installed version's entry plus any newer-than-last-run entries. Claude Code auto-updates between sessions, so checking only when `claude update` upgrades misses the case where the version moved silently — this step fires every run regardless of what `claude update` reports. Cover new features, breaking changes, settings/hooks schema changes, and notable bug fixes. Skip trivial entries (typo fixes, internal refactors).

Check for interesting new formulae and casks from step 1's `==> New Formulae` / `==> New Casks` output. Highlight any relevant to the user's setup (developer tools, terminal utilities, productivity apps) with a one-line description. Don't overwhelm; surface only genuinely interesting additions.

Link each tool name so the user can research it: render the name as a markdown link, e.g. `[pitchfork](https://github.com/jdx/pitchfork)`. Get the homepage URL from `brew info <name>` (the first URL line, above the `From:` Homebrew-formula line). Prefer the project's GitHub repo when the homepage is a GitHub URL or you can readily identify the repo; otherwise link the homepage `brew info` reports. Don't guess a GitHub URL you haven't confirmed — fall back to the homepage.

## Report format

Structure the report as sections with the emojis below. Section headers are organizational only (no severity meaning). Inside sections, prefix individual items with a severity emoji ONLY when they need attention; routine items stay unprefixed.

### Section headers (use exactly these)

- `### 📦 Brewfile formulae` — formula upgrades
- `### ⚙️ mise tools` — mise-managed tool upgrades
- `### 🤖 Claude Code` — include current version in the header, e.g. `### 🤖 Claude Code (2.1.148)`
- `### 🍎 Mac App Store` — mas outdated results
- `### 🧹 Cleanup` — cache pruning and `brew cleanup` results
- `### ✨ New & noteworthy` — interesting new formulae/casks

Omit empty sections (e.g. if nothing was upgraded in mise, drop the section).

### Per-item severity

Use these inline at the start of a bullet, and only when the item is not routine:

- 🔴 **Action required** — the user must do something (run a manual command requiring sudo/password, resolve a config conflict, etc.). Examples: `mas upgrade` needs the password, a breaking-change setting needs migration, a hook misconfiguration surfaced during update.
- 🟡 **Worth attention** — informational but the user may want to know. Examples: major version bumps in Brewfile packages, Claude Code schema/hook changes that could affect existing config, new interesting tools worth trying, deprecations.
- (no emoji) — routine. Patch/minor bumps with no breaking changes, "up to date" results, cache stats, bug fixes the user doesn't need to act on.

Do NOT use green/✅ for routine items — absence of emoji means routine. Reserve emojis for signal.

### Example

```
### 📦 Brewfile formulae
- awscli 2.34.51 → 2.34.52 (patch)
- 🟡 deno 2.7.14 → 3.0.0 (major) — breaking changes to Deno.serve API
- summarize 0.15.2 → 0.16.1 (minor)

### 🤖 Claude Code (2.1.148)
- 🔴 /simplify renamed to /code-review — update any scripts referencing /simplify
- Bug fix: Bash tool exit code 127 regression resolved

### 🍎 Mac App Store
- 🔴 Tailscale 1.96.5 → 1.98.2 — run `mas upgrade` yourself (needs password)

### 🧹 Cleanup
- Pruned chrome-148.0.7778.178 → 341 MB reclaimed
- brew cleanup → 21.6 MB freed
```
