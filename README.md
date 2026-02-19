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
4. Install AI agent tool configs (Claude Code, Codex)
5. Remind about apps needing manual installation

Use `--skip-brew` to skip Homebrew installation and only symlink files.

## What's managed

**Shell & editor:** `.zshrc`, `.alias`, `.vimrc`, `.tmux.conf`

**Git:** `.gitconfig`, `.gitignore_global` (machine-specific settings via `~/.gitconfig.local`)

**Tool configs:** `starship.toml`, `ghostty/config`, `mise/config.toml`

**AI agent configs:**
- `dotagents/AGENTS.md` symlinked to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`
- `dotclaude/settings.json` symlinked to `~/.claude/settings.json`
- `dotclaude/statusline.sh` symlinked to `~/.claude/statusline.sh`
- `dotcodex/config.toml` merged into `~/.codex/config.toml`

**Custom Claude Code commands:** `.claude/commands/` contains project-level slash commands.

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
