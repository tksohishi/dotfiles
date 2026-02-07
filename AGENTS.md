# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

Personal dotfiles repository for macOS/Linux. Manages shell configs, editor settings, git config, and tool preferences via symlinks from `~/.dotfiles/` to `$HOME`.

## Setup and Deployment

The `bootstrap.sh` script symlinks files listed in `list` to the home directory. It backs up existing files (appends `.org`) before creating symlinks. Run `./bootstrap.sh` and confirm with "yes" to deploy.

Prerequisites (install via homebrew): `starship` (prompt), `zoxide` (directory jumping), `mise` (runtime manager).

## Architecture

**Single shell config:** `.zshrc` is the only shell config, loaded directly by zsh (no oh-my-zsh). It handles environment, history, completion, keybindings, PATH, tool initialization (mise, zoxide, starship), and sources `.alias`.

**Local override pattern:** Machine-specific overrides via `.local` suffix files (`.zshrc.local`, `.alias.local`, `.gitconfig.local`). These are not tracked in git.

**Aliases:** `.alias` contains shared aliases sourced by `.zshrc`.

**Archived configs:** Legacy configs are preserved in `_archive/` but no longer active.

## Key Conventions

- Keep configs minimal and simple
- `vim` is the default editor everywhere (shell EDITOR, git core.editor, tmux vi-keys)
- Git config includes `~/.gitconfig.local` for machine-specific settings (e.g., work email)
- Indentation: 4 spaces by default (`.editorconfig`), 2 spaces for `.coffee` and `.html`

## When Editing Dotfiles

- Changes to `.alias` affect the zsh shell
- Changes to `.zshrc` affect zsh directly
- The `list` file must be updated when adding new dotfiles that need symlinking

## Workflow

- The working directory is already `~/.dotfiles/`, no need to specify paths with `-C` or `cd`
- When changing a group of related files for a single purpose, commit and push together before moving on
