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

4. Audit Claude Code plugins:
   - Read `enabledPlugins` from `~/.dotfiles/dotclaude/settings.json` (using jq)
   - Read installed plugins from `~/.claude/plugins/installed_plugins.json` (using jq)
   - List any plugins that are enabled but not installed, and suggest the `/plugin install` command for each
   - List any plugins that are installed but not enabled, and ask whether to enable or uninstall them

5. Audit Codex auto-learned rules:
   - Read `~/.codex/rules/default.rules` and compare against tracked `~/.dotfiles/dotcodex/rules/default.rules`
   - List new auto-learned patterns that look reusable
   - Skip one-off patterns with hardcoded file paths, commit messages, or URLs
   - Suggest useful patterns to import into `~/.dotfiles/dotclaude/settings.json` (source of truth)
   - After import, remind to run `bun scripts/agent-commands.ts sync-allowlist`

6. Wait for the user to decide what to do before making any changes.
