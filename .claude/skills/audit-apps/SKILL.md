---
name: audit-apps
description: Audit installed apps against the Brewfile and suggest changes
---

Audit the current machine's installed packages against the Brewfile at `~/.dotfiles/Brewfile`.

Follow these steps:

1. **Homebrew packages:**
   - Run `brew bundle cleanup` to list packages not in the Brewfile
   - Run `brew bundle check --verbose` to list packages in the Brewfile that aren't installed
   - For packages that need updates (not truly missing), note them as needing `brew upgrade`

2. **GUI apps:**
   - Run `ls /Applications/` and cross-check against casks and MAS entries in the Brewfile
   - Check `# Manual install:` comments in the Brewfile for known unmanaged apps
   - For untracked apps, check `brew search` and `mas search` to see if they're available

3. **Claude Code plugins:**
   - Read `enabledPlugins` from `~/.dotfiles/dotclaude/settings.json` (using jq)
   - Read installed plugins from `~/.claude/plugins/installed_plugins.json` (using jq)
   - List marketplace plugins from `ls ~/.claude/plugins/marketplaces/*/external_plugins/`
   - Marketplace plugins (with `.mcp.json`) work without `enabledPlugins` entries; don't flag those as mismatches
   - Only flag installed-but-not-enabled for non-marketplace plugins

4. **Codex auto-learned rules:**
   - Diff `~/.codex/rules/default.rules` against tracked `~/.dotfiles/dotcodex/rules/default.rules`
   - List new auto-learned patterns that look reusable (skip one-off patterns with hardcoded paths/URLs)
   - Suggest importing useful patterns into `~/.dotfiles/dotclaude/settings.json` (source of truth)

5. **uv Python cache:**
   - Run `uv python list --only-installed` and `mise ls python`
   - For non-mise Python versions, check `brew uses --installed python@<version>` to see if they're brew dependencies
   - Only flag versions that are truly stale (not used by mise or any brew formula)

6. **Present results in three categories with emoji headers:**

   **🟢 OK** — things that are in sync, no action needed. Keep brief (one-liners).

   **🟡 Warning** — minor drift or potential issues, not urgent. E.g. packages needing upgrade, Python versions kept as brew dependencies.

   **🔴 Action Needed** — things that require a decision. E.g. untracked apps, missing packages, stale rules. List each with a suggested action.

7. Wait for the user to decide what to do before making any changes.
