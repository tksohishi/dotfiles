---
name: install-app
description: Install an app via Homebrew and add it to the Brewfile
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

2. Add to Claude Code:
   - Run `claude mcp add --scope user <name> -- <command> [args...]`
   - Verify with `claude mcp list`

3. Add to Codex:
   - Run `codex mcp add <name> -- <command> [args...]`

4. Track in dotfiles (source of truth: `dotcodex/config.toml`):
   - Read `~/.dotfiles/dotcodex/config.toml`
   - Add a `[mcp_servers.<name>]` entry with `command` and `args` fields
   - This is what `install.sh` uses to set up MCP servers on new machines

5. Commit and push:
   - `git add dotcodex/config.toml`
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

5. Permission rules (usually none needed):
   - Auto mode's classifier handles approval; do NOT proactively suggest `allow` rules for new CLI tools. Add an allow rule only reactively, when a safe command demonstrably keeps triggering prompts.
   - If the tool has destructive operations the classifier might wave through (deletes data, mutates remote state), suggest an `ask` rule for those subcommands and get the user's confirmation before adding it.
