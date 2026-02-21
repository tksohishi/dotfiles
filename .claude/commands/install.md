---
description: Install an app via Homebrew and add it to the Brewfile
argument-hint: <app-name or mcp-server-name>
allowed-tools: [Bash, Read, Edit, Write, WebSearch, WebFetch]
---

The user wants to install: $ARGUMENTS

First, determine whether this is an **MCP server** or a **Homebrew package**:
- If the argument contains "mcp", or you recognize it as a known MCP server (e.g. context7, playwright, sentry, sequential-thinking), treat it as an MCP server
- Otherwise treat it as a Homebrew package

---

## Path A: MCP Server

1. Research the MCP server:
   - Search the web for the official install command (usually an npx command or HTTP URL)
   - Determine the server name, command, and any required environment variables

2. Add to Claude Code (user scope, so it's tracked in the symlinked settings.json):
   - Run `claude mcp add --scope user <name> -- <command> [args...]`
   - Verify with `claude mcp list`

3. Add to Codex:
   - Run `codex mcp add <name> -- <command> [args...]`
   - Also add the `[mcp_servers.<name>]` entry to `~/.dotfiles/dotcodex/config.toml` so install.sh carries it to new machines

4. Commit and push:
   - `git add dotclaude/settings.json dotcodex/config.toml`
   - Commit with message like "Add <name> MCP server"
   - `git push origin main`

---

## Path B: Homebrew Package

1. Determine the install source (formula, cask, or Mac App Store):
   - Run `brew search $ARGUMENTS` to find matching formulae and casks
   - Run `mas search $ARGUMENTS` to check the Mac App Store
   - If matches exist in multiple sources, show the options and ask the user which one to install

2. Add the app to the Brewfile at `~/.dotfiles/Brewfile`:
   - Read the Brewfile first
   - Add the appropriate line in the correct section, maintaining alphabetical order within each section:
     - Formula: `brew "<name>"` (in the brew section)
     - Cask: `cask "<name>"` (in the cask section)
     - Mac App Store: `mas "<name>", id: <id>` (in the mas section)
   - Keep the existing formatting and ordering

3. Commit and push:
   - `git add Brewfile`
   - Commit with message like "Add <name> to Brewfile"
   - `git push origin main`

4. Install the app:
   - For formulae: run `brew install <name>`
   - For casks: run `brew install --cask <name>`
   - For Mac App Store: tell the user to run `mas install <id>` (requires sudo)

5. Suggest allowlist updates for CLI tools:
   - Skip this step for casks and Mac App Store apps (GUI apps don't need shell permissions)
   - For formulae that provide CLI commands, check if the tool or its safe subcommands would be useful to allow in `~/.dotfiles/dotclaude/settings.json`
   - Assess which subcommands are safe (read-only, non-destructive) vs. disruptive (executes arbitrary code, mutates remote state, deletes data)
   - Suggest specific `Bash(<command> *)` or granular `Bash(<command> <subcommand> *)` rules as appropriate
   - Ask the user before adding any rules
