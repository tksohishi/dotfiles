# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

Personal dotfiles repository for macOS. Manages shell configs, editor settings, git config, tool preferences, and all installed applications (Homebrew packages, casks, and Mac App Store apps) via symlinks and a Brewfile.

## Project Skills
- **audit-apps**: Audit installed apps against the Brewfile and suggest changes. Full instructions: `.claude/skills/audit-apps/SKILL.md`
- **command-permissions**: Manage Claude Code Bash permissions (allow, ask, deny) for a given command. Full instructions: `.claude/skills/command-permissions/SKILL.md`
- **create-hook**: Create an agent hook (PreToolUse / PostToolUse / etc.) and wire it correctly for Claude Code, Codex, or both. Full instructions: `.claude/skills/create-hook/SKILL.md`
- **discover-apps**: Find new Mac tools worth installing. Full instructions: `.claude/skills/discover-apps/SKILL.md`
- **install-app**: Install an app via Homebrew and add it to the Brewfile. Full instructions: `.claude/skills/install-app/SKILL.md`
- **install-skill**: Discover and install an agent skill via bunx skills add -g, then track it in dotagents/skills.txt for new-machine reproducibility. Full instructions: `.claude/skills/install-skill/SKILL.md`
- **sync-allowlist**: Sync command allowlist from Claude Code into Codex. Full instructions: `.claude/skills/sync-allowlist/SKILL.md`
- **uninstall-app**: Uninstall an app via Homebrew and remove it from the Brewfile. Full instructions: `.claude/skills/uninstall-app/SKILL.md`
- **update-apps**: Update all Homebrew packages, casks, and Mac App Store apps. Full instructions: `.claude/skills/update-apps/SKILL.md`

## Architecture

- Machine-specific overrides live in `.local`/`.override` suffix files (`.zshrc.local`, `.alias.local`, `.gitconfig.local`); not tracked in git.
- `_archive/` preserves retired configs intentionally — don't "clean up".

## Non-obvious file behavior

Most files are self-explanatory. These have *why* worth knowing:

- `bin/agent-browser` — wrapper that rejects `--profile <real-Chrome>` invocations to keep agents away from logged-in Chrome state. Bypass by calling `/opt/homebrew/bin/agent-browser` directly.
- `bin/slk` — personal CLI; reads `SLACK_XOXC_TOKEN` + `SLACK_COOKIE_D` from CWD's `.env.local` because the creds are per-user (each developer has their own Slack session). Bun auto-loads both `.env` and `.env.local`. Not a general rule that secrets go in `.env.local` — app secrets normally belong in `.env`.
- `dotcodex/config.toml` — **merged**, not symlinked, into `~/.codex/config.toml` (Codex overwrites symlinks).
- `dotagents/skills/<name>/SKILL.md` — single source of truth for agent capabilities. Only the `description` frontmatter loads into context until invoked. `install.sh` symlinks each into both `~/.claude/skills/` (Claude scans here) and `~/.agents/skills/` (Codex scans here natively); no per-agent copy to maintain.

## Key Conventions

- Keep configs minimal and simple
- `vim` is the default editor everywhere (shell EDITOR, git core.editor, tmux vi-keys)
- Git config includes `~/.gitconfig.local` for machine-specific settings (e.g., work email)
- No git aliases; git operations are delegated to AI agents
- gog CLI provides Gmail/Calendar access; read commands are auto-approved, write commands prompt for confirmation
- Prefer Homebrew (`brew install`) over global installs via npm, pip, or go. Homebrew keeps everything in the Brewfile and makes setup reproducible.

## When Editing

- The `files` array in `install.sh` must be updated when adding new dotfiles
- New cross-agent capabilities go in `dotagents/skills/<name>/SKILL.md`. `install.sh` symlinks them into both `~/.claude/skills/` and `~/.agents/skills/` automatically; no separate Codex wiring needed (Codex scans `~/.agents/skills/` natively, Claude scans `~/.claude/skills/`).
- Agent hooks live in `dotagents/hooks/` (shared, symlinked to both `~/.claude/hooks/` and `~/.codex/hooks/`). When changing the hook wiring (which hook fires on which event/matcher), update BOTH `dotclaude/settings.json` and the `[hooks]` section in `dotcodex/config.toml`. Hook scripts themselves only need editing once. Codex's `PreToolUse` accepts only `allow`/`deny` (not `ask`); `bash-antipatterns.sh` detects Codex via `has("model")` on the input JSON (Codex includes `model` as a common field; Claude doesn't) and downgrades `ask`→`deny`. Don't use `permission_mode` as the detector — both agents populate it.
- For apps with no Homebrew cask or MAS listing, add a `# Manual install: AppName (URL)` comment to the Brewfile. These are shown as reminders at the end of `install.sh`.
- This is a public repo. Never commit personal information (API keys, tokens, personal URLs, email addresses, domain allowlists, etc.) to `dotagents/`, `dotclaude/`, or `dotcodex/`. Use `.local`/`.override` files for machine-specific or private settings.
- Claude Code allowlist patterns: `Bash(cmd *)` does NOT match bare `cmd`. Use `Bash(cmd*)` (no space) for multi-word commands where collision is impossible (e.g. `gh release list*`). Keep the space form (`Bash(cmd *)`) for broad prefixes where collisions matter (e.g. `ls *` vs `lsof`).
- Use `summarize <url>` to research YouTube links; direct access to YouTube is blocked for agents

## Workflow

- After making changes, always commit and push before moving on
- When changing a group of related files for a single purpose, commit and push together
