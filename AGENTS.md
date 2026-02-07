# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

Personal dotfiles repository for macOS. Manages shell configs, editor settings, git config, and tool preferences via symlinks from `~/.dotfiles/` to `$HOME`.

## Setup and Deployment

The `install.sh` script symlinks dotfiles to `$HOME`. The file list is defined in the script itself. It backs up existing files (appends `.bak`) before creating symlinks. Run `./install.sh` and confirm with "y" to deploy.

Prerequisites (install via homebrew): `starship` (prompt), `zoxide` (directory jumping), `mise` (runtime manager), `ghostty` (terminal).

## Architecture

**Single shell config:** `.zshrc` is the only shell config, loaded directly by zsh (no oh-my-zsh). It handles environment, history, completion, keybindings, PATH, tool initialization (mise, zoxide, starship), and sources `.alias`.

**Local override pattern:** Machine-specific overrides via `.local` suffix files (`.zshrc.local`, `.alias.local`, `.gitconfig.local`). These are not tracked in git.

**Aliases:** `.alias` contains shared aliases sourced by `.zshrc`.

**Archived configs:** Legacy configs are preserved in `_archive/` but no longer active.

## Active Config Files

- `.zshrc` — shell environment, history, completion, keybindings, PATH, tool init
- `.alias` — shared shell aliases
- `.vimrc` — vim settings, key mappings, status line
- `.gitconfig` — user, color, core settings, local include
- `.gitignore_global` — OS/editor/secrets ignore patterns
- `.tmux.conf` — terminal type, mouse, status bar, vi copy mode
- `.config/starship.toml` — prompt with git, python, node, cmd_duration
- `.config/ghostty/config` — font, opacity, window size, tab behavior
- `.config/mise/config.toml` — node and python runtime versions

## Key Conventions

- Keep configs minimal and simple
- `vim` is the default editor everywhere (shell EDITOR, git core.editor, tmux vi-keys)
- Git config includes `~/.gitconfig.local` for machine-specific settings (e.g., work email)
- No git aliases; git operations are delegated to AI agents

## When Editing Dotfiles

- Changes to `.alias` affect the zsh shell
- Changes to `.zshrc` affect zsh directly
- The `files` array in `install.sh` must be updated when adding new dotfiles

## Workflow

- The working directory is already `~/.dotfiles/`, no need to specify paths with `-C` or `cd`
- When changing a group of related files for a single purpose, commit and push together before moving on
