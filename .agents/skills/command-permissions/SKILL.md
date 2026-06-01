---
name: command-permissions
description: Manage Claude Code Bash permissions (allow, ask, deny) for a given command
---

The user wants to manage permissions for: $ARGUMENTS

Manage `Bash(...)` rules across `permissions.allow`, `permissions.ask`, and `permissions.deny` in `~/.dotfiles/dotclaude/settings.json`.

## Approach

Prefer **broad allow + targeted ask** over enumerating every read-only subcommand:

- `Bash(<cmd> *)` in **allow** — auto-approve the command by default.
- `Bash(<cmd> <destructive-sub>*)` in **ask** — prompt before destructive subcommands.
- `Bash(<cmd> <catastrophic-sub>*)` in **deny** — hard-block irreversible or dangerous operations (e.g. `git push --force`, `git reset --hard`).

Claude Code precedence is `deny > ask > allow`, so an entry in `ask` prompts even when a broader `allow` rule matches.

## Steps

1. Read `~/.dotfiles/dotclaude/settings.json`.
2. Search all three arrays (`allow`, `ask`, `deny`) for existing rules matching the command.
3. **If rules already exist:** Show the user what matches in each array and ask what to change: broaden, tighten, move between arrays, remove.
4. **If no rules exist:**
   - Briefly research the command's subcommands. Identify destructive ones (install, uninstall, delete, remove, drop, purge, force, reset, `push --force`, etc.) and catastrophic ones (anything that bypasses safety or is unrecoverable).
   - Default: put `Bash(<cmd> *)` in allow.
   - For each destructive subcommand, add `Bash(<cmd> <sub>*)` to ask.
   - For catastrophic combos, add to deny (see existing entries like `Bash(git push --force *)` as reference).
5. **Wildcard form:** `Bash(cmd *)` does NOT match bare `cmd` (no args). For multi-word patterns where collision is impossible, use the no-space form `Bash(cmd*)` to cover both bare and with-args (e.g. `Bash(brew install*)` matches `brew install` and `brew install foo`). Keep the space form `Bash(cmd *)` for broad single-word prefixes where collision matters (e.g. `ls *` vs `lsof`).
6. Maintain alphabetical order within each array.
7. Validate JSON: `jq empty dotclaude/settings.json`.
8. Commit and push `dotclaude/settings.json`.
9. Report what was added, moved, or removed across which arrays.
