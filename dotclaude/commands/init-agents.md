# /init-agents: Initialize a new project with AGENTS.md

You are initializing a new project with an AGENTS.md-based setup. Follow these steps in order.

## Step 1: Create AGENTS.md

Create `AGENTS.md` at the project root with this structure:

```markdown
# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Overview

<Ask the user: "Describe this project in 1-2 sentences." Use their response here.>
```

Keep it minimal. The user will add sections (Architecture, Key Conventions, etc.) as the project evolves.

## Step 2: Create CLAUDE.md symlink

```bash
ln -s AGENTS.md CLAUDE.md
```

Claude Code only reads `CLAUDE.md` at the project root, so this symlink is required.

## Step 3: Initialize git and commit

If the current directory is not already a git repository, run `git init`.

Stage and commit:

```bash
git add AGENTS.md CLAUDE.md
git commit -m "Initialize project with AGENTS.md"
```

## Important notes

- Always ask for the project overview before writing AGENTS.md
- Never overwrite existing AGENTS.md or CLAUDE.md
- The CLAUDE.md symlink is critical; without it Claude Code won't read AGENTS.md
