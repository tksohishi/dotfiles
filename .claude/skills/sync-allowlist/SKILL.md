---
name: sync-allowlist
description: Sync command allowlist from Claude Code into Codex
---

Sync command allowlist from `~/.dotfiles/dotclaude/settings.json` into Codex.

Follow these steps:

1. Run `bun scripts/agent-commands.ts sync-allowlist`
2. Run `scripts/sync-codex-config.sh`
3. Copy `~/.dotfiles/dotcodex/rules/default.rules` to `~/.codex/rules/default.rules`
4. Validate generated files:
   - `codex execpolicy check --pretty --rules dotcodex/rules/default.rules -- git status` (should return `"decision": "allow"`)
   - `codex execpolicy check --pretty --rules dotcodex/rules/default.rules -- sudo rm` (should return `"decision": "forbidden"`)
   - If any check fails, stop and report the error
5. Show the changed files, then commit and push
