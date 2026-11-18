---
name: sync-allowlist
description: Sync command allowlist from Claude Code into Codex
model: opus
---

Sync command allowlist from `~/.dotfiles/dotclaude/settings.json` into Codex.

Follow these steps:

1. Run `bun scripts/sync-allowlist.ts`
2. Copy `~/.dotfiles/dotcodex/rules/default.rules` to `~/.codex/rules/default.rules`
3. Validate the generated file: `codex execpolicy check --pretty --rules dotcodex/rules/default.rules -- sudo rm` should return `"decision": "forbidden"`. If it doesn't, stop and report the error
4. Show the changed files, then commit and push
