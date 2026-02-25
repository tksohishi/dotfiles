# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

Personal dotfiles repository for macOS. Manages shell configs, editor settings, git config, tool preferences, and all installed applications (Homebrew packages, casks, and Mac App Store apps) via symlinks and a Brewfile.

## Setup and Deployment

The `install.sh` script installs Homebrew (if missing), runs `brew bundle` to install all packages from the `Brewfile`, then symlinks dotfiles to `$HOME`. The dotfile list is defined in the script itself. It backs up existing files (appends `.bak`) before creating symlinks. Run `./install.sh` and confirm with "y" to deploy.

## Architecture

**Single shell config:** `.zshrc` is the only shell config, loaded directly by zsh (no oh-my-zsh). It handles environment, history, completion, keybindings, PATH, tool initialization (mise, zoxide, starship), and sources `.alias`.

**Local override pattern:** Machine-specific overrides via `.local` suffix files (`.zshrc.local`, `.alias.local`, `.gitconfig.local`). These are not tracked in git.

**Aliases:** `.alias` contains shared aliases sourced by `.zshrc`.

**Archived configs:** Legacy configs are preserved in `_archive/` but no longer active.

## Active Config Files

- `Brewfile` — all Homebrew packages, casks, Mac App Store apps, and manual install reminders
- `.zshrc` — shell environment, history, completion, keybindings, PATH, tool init
- `.alias` — shared shell aliases
- `.vimrc` — vim settings, key mappings, status line
- `.gitconfig` — user, color, core settings, local include
- `.gitignore_global` — OS/editor/secrets ignore patterns
- `.tmux.conf` — terminal type, mouse, status bar, vi copy mode
- `.config/starship.toml` — prompt with git, python, node, cmd_duration
- `.config/ghostty/config` — font, opacity, window size, tab behavior
- `.config/mise/config.toml` — node and python runtime versions
- `hooks/pre-commit` — blocks personal info (emails, API keys, tokens) from public files
- `dotagents/AGENTS.md` — global agent instructions, symlinked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.gemini/GEMINI.md`
- `dotclaude/commands/` — global Claude Code commands (symlinked as `~/.claude/commands/`), e.g. `/init-agents`
- `.claude/commands/` — project-local Claude Code commands, e.g. `/discover`
- `dotclaude/keybindings.json` — Claude Code keybindings, unbinds Ctrl+B (see [#22626](https://github.com/anthropics/claude-code/issues/22626))
- `dotclaude/settings.json` — Claude Code global settings, symlinked to `~/.claude/settings.json`
- `dotcodex/config.toml` — OpenAI Codex global settings, merged into `~/.codex/config.toml`
- `scripts/setup-gog.sh` — one-time Google Cloud project + gog CLI auth setup

## Key Conventions

- Keep configs minimal and simple
- `vim` is the default editor everywhere (shell EDITOR, git core.editor, tmux vi-keys)
- Git config includes `~/.gitconfig.local` for machine-specific settings (e.g., work email)
- No git aliases; git operations are delegated to AI agents
- gog CLI provides Gmail/Calendar access; read commands are auto-approved, write commands prompt for confirmation

## When Editing

- Changes to `.alias` affect the zsh shell
- Changes to `.zshrc` affect zsh directly
- The `files` array in `install.sh` must be updated when adding new dotfiles
- To add or remove packages/apps, use the `/install` and `/uninstall` commands
- `/install` also handles MCP servers: it adds them to both Claude Code and Codex, and tracks configs in dotfiles
- For apps with no Homebrew cask or MAS listing, add a `# Manual install: AppName (URL)` comment to the Brewfile. These are shown as reminders at the end of `install.sh`.
- This is a public repo. Never commit personal information (API keys, tokens, personal URLs, email addresses, domain allowlists, etc.) to `dotagents/`, `dotclaude/`, or `dotcodex/`. Use `.local`/`.override` files for machine-specific or private settings.

## Terminology

- "AGENTS" or "AGENTS.md" = this file (`AGENTS.md` at the repo root, symlinked as `CLAUDE.md`)
- "the global AGENTS" = `dotagents/AGENTS.md` (symlinked to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`)

## Workflow

- The working directory is already `~/.dotfiles/`. Do NOT use `git -C`, `cd`, or absolute paths in git/shell commands. Just run `git status`, `git add .zshrc`, etc. directly.
- After making changes, always commit and push before moving on
- When changing a group of related files for a single purpose, commit and push together
