# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository for macOS/Linux. Manages shell configs, editor settings, git config, and tool preferences via symlinks from `~/.dotfiles/` to `$HOME`.

## Setup and Deployment

The `bootstrap.sh` script symlinks files listed in `list` to the home directory. It backs up existing files (appends `.org`) before creating symlinks. Run `./bootstrap.sh` and confirm with "yes" to deploy.

The `list` file controls which dotfiles get symlinked. The `.zshrc` file is notably **not** in `list` because oh-my-zsh manages it separately.

## Architecture

**Two shell configurations exist in parallel:**
- **Bash:** `.bash_profile` sources `.bashrc`, which handles PATH, ssh-agent, mise activation, and sources `.alias`
- **Zsh:** `.zshrc` is a standalone config (prompt, completion, history, VCS info). `.zsh_custom/custom.zsh` is loaded by oh-my-zsh and sources `.alias`

**Local override pattern:** Both shells support machine-specific overrides via `.local` suffix files (`.bashrc.local`, `.zshrc.local`, `.zshrc.mine`, `.alias.local`, `.gitconfig.local`). These are not tracked in git.

**Shared aliases:** `.alias` is sourced by both bash and zsh configs, so aliases must be compatible with both shells.

## Key Conventions

- Keep configs minimal and simple
- `vim` is the default editor everywhere (shell EDITOR, git core.editor, tmux vi-keys)
- Git push default is `nothing` (requires explicit remote/branch), this is intentional for safety
- Git config includes `~/.gitconfig.local` for machine-specific settings (e.g., work email)
- Indentation: 4 spaces by default (`.editorconfig`), 2 spaces for `.coffee` and `.html`

## When Editing Dotfiles

- Changes to `.alias` affect both bash and zsh
- Changes to `.bashrc` only affect bash; changes to `.zshrc` or `.zsh_custom/custom.zsh` only affect zsh
- The `list` file must be updated when adding new dotfiles that need symlinking
- Test shell config changes in both bash and zsh if they touch shared files
