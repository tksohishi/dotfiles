---
description: Manage Claude Code command allowlist (add, remove, modify)
allowed-tools: Read, Edit, Bash
argument-hint: <command>
---

# /command-permissions: Manage Claude Code command allowlist

The user wants to manage permissions for: $ARGUMENTS

Manage `Bash(...)` permission rules in the `permissions.allow` array in `~/.dotfiles/dotclaude/settings.json`.

## Steps

1. Read `~/.dotfiles/dotclaude/settings.json`
2. Search for existing rules matching the command (e.g. for `gh`, find all `Bash(gh *)`, `Bash(gh pr view *)`, etc.)
3. **If rules already exist:** Show the user what's currently allowed, then ask what they want to do:
   - Remove some or all rules
   - Add more subcommands
   - Modify existing rules (e.g. tighten wildcards, remove dangerous subcommands)
4. **If no rules exist:** Add new rules:
   - Research the command's subcommands to understand which are safe and which are dangerous
   - If the command has useful subcommands, add wildcard rules per subcommand group rather than a blanket `<command> *`
   - `Bash(cmd *)` does NOT match bare `cmd` (no args). For multi-word commands where collision is impossible, use the no-space form `Bash(cmd*)` to cover both bare and with-args (e.g. `Bash(gh release list*)` matches `gh release list` and `gh release list --json tagName`). Keep the space form `Bash(cmd *)` for broad single-word prefixes where collisions matter (e.g. `ls *` to avoid matching `lsof`).
   - If the command is simple or read-only, a single `Bash(<command> *)` is fine
   - Use the existing rules in the file as a style reference
5. **Safety check (for new and modified rules):** Exclude subcommands that can delete, overwrite, or destructively modify files, data, or remote state. Examples: `rm`, `delete`, `drop`, `push --force`, `reset --hard`, `prune`. If excluding dangerous subcommands leaves an incomplete set, list what was excluded and why, and ask the user if they want to add any of them anyway.
6. Maintain alphabetical order within the allow array
7. Sync to Codex and Gemini:
   - Run `bun scripts/agent-commands.ts sync-allowlist`
   - Copy `dotcodex/rules/default.rules` to `~/.codex/rules/default.rules`
   - Run `scripts/sync-gemini-settings.sh`
8. Commit and push all changed files together (`dotclaude/settings.json`, `dotcodex/rules/default.rules`, `dotgemini/settings.json`)
9. Report what was added, removed, or modified
