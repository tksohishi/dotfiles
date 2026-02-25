---
description: Manage Claude Code command allowlist (add, remove, modify)
allowed-tools: Read, Edit
argument-hint: <command>
---

# /claude-commands: Manage Claude Code command allowlist

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
   - If the command has useful subcommands, add wildcard rules per subcommand group (e.g. `gh pr view *`, `gh pr list *`) rather than a blanket `gh *`
   - If the command is simple or read-only, a single `Bash(<command> *)` is fine
   - Use the existing rules in the file as a style reference
5. **Safety check (for new and modified rules):** Exclude subcommands that can delete, overwrite, or destructively modify files, data, or remote state. Examples: `rm`, `delete`, `drop`, `push --force`, `reset --hard`, `prune`. If excluding dangerous subcommands leaves an incomplete set, list what was excluded and why, and ask the user if they want to add any of them anyway.
6. Maintain alphabetical order within the allow array
7. Report what was added, removed, or modified
