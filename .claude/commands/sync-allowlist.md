---
description: Sync command allowlists across Claude, Codex, and Gemini
allowed-tools: [Bash, Read]
---

Sync command allowlists from `~/.dotfiles/dotclaude/settings.json` into Codex and Gemini.

Follow these steps:

1. Run `bun scripts/agent-commands.ts sync-allowlist`
2. Run `scripts/sync-codex-config.sh`
3. Run `scripts/sync-gemini-settings.sh`
4. Copy `~/.dotfiles/dotcodex/rules/default.rules` to `~/.codex/rules/default.rules`
5. Validate generated files:
   - `jq . dotgemini/settings.json > /dev/null` (valid JSON)
   - `codex execpolicy check --pretty --rules dotcodex/rules/default.rules -- git status` (should return `"decision": "allow"`)
   - `codex execpolicy check --pretty --rules dotcodex/rules/default.rules -- sudo rm` (should return `"decision": "forbidden"`)
   - If any check fails, stop and report the error
6. Show the changed files, then commit and push
