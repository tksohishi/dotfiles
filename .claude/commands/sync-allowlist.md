---
description: Sync command allowlists across Claude, Codex, and Gemini
allowed-tools: [Bash, Read]
---

Sync command allowlists from `~/.dotfiles/dotclaude/settings.json` into Codex and Gemini.

Follow these steps:

1. Run `bun scripts/agent-commands.ts sync-allowlist`
2. Run `scripts/sync-codex-config.sh`
3. Merge `~/.dotfiles/dotgemini/settings.json` into `~/.gemini/settings.json` and overwrite only the `tools` key
4. Copy `~/.dotfiles/dotcodex/rules/default.rules` to `~/.codex/rules/default.rules`
5. Show the changed files, then commit and push
