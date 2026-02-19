# /init-agents: Initialize a new project with AGENTS.md

You are initializing a new project with an AGENTS.md-based setup. Follow these steps in order.

## Step 1: Detect or ask project type

Check the current directory for existing files to determine the project type:

- **Node/TypeScript**: `package.json`, `tsconfig.json`, or `.ts`/`.js` files present
- **Python**: `pyproject.toml`, `setup.py`, `setup.cfg`, or `.py` files present
- **Non-coding / docs**: None of the above, or the directory is empty

If the directory is empty or ambiguous (signals for multiple types), ask the user using AskUserQuestion:

```
Which project type is this?
Options: Node/TypeScript, Python, Non-coding / documentation
```

Store the result as the project type for the remaining steps.

## Step 2: Initialize git

If the current directory is not already a git repository, run `git init`.

## Step 3: Create AGENTS.md

Create `AGENTS.md` at the project root. Use the detected project type to fill in specifics.

The file MUST include these sections with content tailored to the project:

### All project types

```markdown
# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

<Ask the user: "Describe this project in 1-2 sentences." Use their response here.>

## Architecture

<Describe the directory structure and how the project is organized. For existing projects, read the actual structure. For new/empty projects, describe the intended structure based on the scaffolded files.>

## Key Conventions

<List conventions based on project type — see below.>

## When Editing

<List project-specific editing notes — see below.>
```

### Node/TypeScript conventions to include

- Use pnpm, not npm, for package management
- TypeScript strict mode
- Note the test runner and build commands from package.json scripts (if they exist)
- Note the module system (ESM or CJS) based on package.json `"type"` field

### Python conventions to include

- Use uv for dependency management and virtual environments
- pyproject.toml is the single source for project metadata and dependencies
- Note the test runner (pytest if present)

### Non-coding conventions to include

- Documentation-focused guidance
- Note the primary format (Markdown, etc.)

## Step 4: Create CLAUDE.md symlink

Create a symlink so Claude Code recognizes the project instructions:

```bash
ln -s AGENTS.md CLAUDE.md
```

Claude Code only reads `CLAUDE.md` at the project root, so this symlink is required.

## Step 5: Create or update .gitignore

If `.gitignore` does not exist, create one with the entries below. If it already exists, check for missing entries from the list below and append them. Do not duplicate entries or reorganize the existing file.

### Node/TypeScript

```
node_modules/
dist/
.env
.env.*
!.env.example
tmp/
*.tsbuildinfo
```

### Python

```
__pycache__/
*.pyc
.venv/
dist/
*.egg-info/
.env
.env.*
!.env.example
tmp/
```

### Non-coding

```
.env
tmp/
.DS_Store
```

## Step 6: Scaffold project files (empty projects only)

**Skip this step entirely** if any project files already exist (package.json, tsconfig.json, pyproject.toml, setup.py, src/, etc.). Existing projects were likely set up by a dedicated tool (create-next-app, create-vite, uv init, etc.) and scaffolding would conflict.

Only proceed with scaffolding if the directory was empty (or contained only git/editor config files) when the command started. Even then, ask first:

```
Scaffold starter project files? (Select "No" if you plan to use a project generator like create-next-app, create-vite, etc.)
Options: Yes, No
```

If the user selects No, skip to Step 7.

### Node/TypeScript

Ask the user their preferences using AskUserQuestion:

1. "ES modules or CommonJS?" (options: ESM, CJS) — default to ESM
2. "Use a src/ directory for source code?" (options: Yes, No) — default to Yes

Then create:

- **package.json** with:
  - `"type": "module"` if ESM was chosen
  - `"scripts"` with `build`, `test`, and `dev` stubs
  - pnpm as the expected package manager
- **tsconfig.json** with strict mode, appropriate module/target settings for the chosen module system
- **src/index.ts** (or `index.ts` if no src/) with a minimal placeholder

After creating files, run `pnpm install` to generate the lockfile.

### Python

Create:

- **pyproject.toml** with:
  - `[project]` table with name (from directory name), version `"0.1.0"`, `requires-python >= "3.12"`
  - `[build-system]` using hatchling
  - `[tool.pytest.ini_options]` with `testpaths = ["tests"]`
- **src/<package_name>/__init__.py** (package name derived from directory name, lowercased, underscores for hyphens)
- **tests/__init__.py**

After creating files, run `uv sync` to create the virtual environment and lockfile.

### Non-coding

Skip scaffolding. The AGENTS.md and .gitignore are sufficient.

## Step 7: Initial commit

Stage all created files and create a commit:

```bash
git add -A
git commit -m "Initialize project with AGENTS.md"
```

## Important notes

- Always ask for the project overview (Step 3) before writing AGENTS.md
- Never overwrite existing files; only create new ones
- The CLAUDE.md symlink is critical; without it Claude Code won't read AGENTS.md
- Keep all generated files minimal; the user will expand them as needed
