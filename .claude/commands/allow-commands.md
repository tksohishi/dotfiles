---
description: Add a command to the Claude Code allowlist
allowed-tools: Read, Edit
argument-hint: <command>
---

# /allow-commands: Add a command to the Claude Code allowlist

The user wants to allow: $ARGUMENTS

Add a `Bash(...)` permission rule to the `permissions.allow` array in `~/.dotfiles/dotclaude/settings.json`.

## Steps

1. Read `~/.dotfiles/dotclaude/settings.json`
2. Research the command's subcommands to understand which are safe and which are dangerous
3. Determine the appropriate rules:
   - If the command has useful subcommands, add wildcard rules per subcommand group (e.g. `gh pr view *`, `gh pr list *`) rather than a blanket `gh *`
   - If the command is simple or read-only, a single `Bash(<command> *)` is fine
   - Use the existing rules in the file as a style reference
4. **Safety check:** Exclude subcommands that can delete, overwrite, or destructively modify files, data, or remote state. Examples: `rm`, `delete`, `drop`, `push --force`, `reset --hard`, `prune`. If excluding dangerous subcommands leaves an incomplete set, list what was excluded and why, and ask the user if they want to add any of them anyway.
5. Check for duplicates; don't add rules that already exist or are covered by existing wildcards
6. Add the new rule(s) in the appropriate alphabetical position within the allow array
7. Report what was added and what was excluded (if anything)
