# dotfiles

macOS machine setup: shell configs, editor settings, git config, tool preferences, and all applications managed via Homebrew and the Mac App Store.

## Setup

```shell
git clone git@github.com:tksohishi/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

This will:

1. Install Homebrew (if not already installed)
2. Install all CLI tools, GUI apps, and App Store apps from the `Brewfile`
3. Symlink dotfiles to `$HOME`
4. Install AI agent tool configs (Claude Code, Gemini CLI, Codex)
5. Remind about apps needing manual installation

Use `--skip-brew` to skip Homebrew installation and only symlink files.

## What's managed

**Shell & editor:** `.zshrc`, `.alias`, `.vimrc`, `.tmux.conf`

**Git:** `.gitconfig`, `.gitignore_global` (machine-specific settings via `~/.gitconfig.local`)

**Tool configs:** `starship.toml`, `ghostty/config`, `mise/config.toml`

**AI agent configs:**
- `dotagents/AGENTS.md` symlinked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.gemini/GEMINI.md`
- `dotclaude/settings.json` symlinked to `~/.claude/settings.json`
- `dotclaude/statusline.sh` symlinked to `~/.claude/statusline.sh`
- `dotgemini/commands/` symlinked to `~/.gemini/commands/`
- `dotcodex/config.toml` merged into `~/.codex/config.toml`
- `dotcodex/skills/.dotfiles/` symlinked to `~/.codex/skills/.dotfiles/`

**Global agent commands:** `dotclaude/commands/*.md` is the source of truth. `scripts/agent-commands.sh sync` generates Gemini command TOML files and Codex skills from that source.

Command lifecycle helpers:

```shell
scripts/agent-commands.sh create <name>
scripts/agent-commands.sh delete <name>
scripts/agent-commands.sh sync
```

**Project commands:** `.claude/commands/` contains project-level Claude commands.

**Scripts:** `scripts/setup-gog.sh` sets up the gog CLI for Gmail/Calendar access via Google Cloud.

## Adding or removing packages

Use the `/install` and `/uninstall` Claude Code commands, or edit the `Brewfile` directly and run:

```shell
brew bundle
```

To check for installed packages not listed in the Brewfile:

```shell
brew bundle cleanup
```

## Local overrides

Machine-specific settings go in `.local` suffix files (not tracked in git):

- `~/.zshrc.local`
- `~/.alias.local`
- `~/.gitconfig.local`
