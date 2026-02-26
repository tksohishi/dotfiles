---
name: "init-agents"
description: "/init-agents: Initialize a new project with AGENTS.md"
---

Use this skill when the user asks to run `/init-agents`.

# /init-agents: Initialize a new project with AGENTS.md

You are initializing a new project with an AGENTS.md-based setup. Follow these steps in order.

## Step 1: Gather context

Check for existing materials in the project root and common locations:

- `README.md`, `README`
- `.cursorrules`, `.cursor/rules`
- `CONTRIBUTING.md`
- `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, or similar manifest files
- Existing `AGENTS.md` or `CLAUDE.md` (if found, stop and inform the user)

If the project has source code, explore the codebase to understand the structure, key entrypoints, and tech stack.

## Step 2: Create AGENTS.md

If the project has no source code yet (empty or brand new repo), ask the user to describe the project and create a minimal AGENTS.md:

```markdown
# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Summary

<1-2 sentence project description from the user>
```

If the project has existing source code, create a more complete AGENTS.md based on what you found:

```markdown
# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Summary

<1-2 sentence project description, derived from README or codebase>

## Tech Stack

<Languages, frameworks, key dependencies; keep it to a short list>

## Architecture

<Key entrypoints and how the project is organized. Don't list every file; focus on what an agent needs to know to navigate the codebase effectively.>
```

Guidelines:
- Be concise; agents scan, they don't read novels
- Only include information that helps an agent work on the codebase
- Don't pad with generic advice (e.g. "write clean code")
- The user will add sections (Key Conventions, Setup, etc.) as the project evolves

## Step 3: Create CLAUDE.md symlink

```bash
ln -s AGENTS.md CLAUDE.md
```

Claude Code only reads `CLAUDE.md` at the project root, so this symlink is required.

## Step 4: Initialize git and commit

If the current directory is not already a git repository, run `git init`.

Stage and commit:

```bash
git add AGENTS.md CLAUDE.md
git commit -m "Initialize project with AGENTS.md"
```

## Important notes

- Never overwrite existing AGENTS.md or CLAUDE.md
- The CLAUDE.md symlink is critical; without it Claude Code won't read AGENTS.md
