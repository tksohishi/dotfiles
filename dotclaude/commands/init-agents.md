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

AGENTS.md is a constraint system to prevent specific mistakes, not documentation. The agent can already read your code, infer patterns, and figure out conventions. Focus on what it *cannot* figure out on its own.

### Design principles

- **Start minimal, add reactively.** Only add a rule when you notice the agent making the same mistake twice.
- **The litmus test for each line:** "Would removing this cause the agent to make mistakes?" If not, cut it.
- **Examples over prose.** Point to canonical files (e.g. "Forms: follow `app/components/DashForm.tsx`") rather than describing patterns.
- **Don't duplicate what tools enforce.** If a linter or formatter handles it, don't add it here.
- **Anchor to stable things.** Commands, boundaries, and architectural decisions stay accurate. File-by-file descriptions go stale fast.

### Template for new projects (no source code yet)

```markdown
# AGENTS.md

## Overview

<1-2 sentence project description>

## Commands

<exact build/test/lint/run commands; the single most-referenced section>

## Boundaries

<"never do" rules: files not to touch, secrets handling, etc.>
```

### Template for existing projects

```markdown
# AGENTS.md

## Overview

<1-2 sentence project description, derived from README or codebase>

## Commands

<exact build/test/lint/run commands the agent cannot guess>

## Architecture

<Key entrypoints and how the project is organized. Don't list every file; focus on non-obvious structure, especially in monorepos. Point to canonical example files.>

## Boundaries

<"never do" rules: files not to touch, directories to avoid, secrets, migrations, etc.>

## Gotchas

<Non-obvious things that will cause the agent to produce broken code. Only include if they exist.>
```

### What NOT to include

- Generic advice ("write clean code", "follow best practices")
- Standard language conventions the agent already knows
- Detailed API documentation (link to it instead)
- File-by-file descriptions (the agent can read files)
- Information that changes frequently
- Style rules that a linter/formatter handles

### Size target

Keep it under 150 lines. The agent's instruction-following quality degrades as the file grows. Shorter is better.

## Step 3: Create CLAUDE.md symlink

```bash
ln -s AGENTS.md CLAUDE.md
```

Claude Code reads both `CLAUDE.md` and `AGENTS.md`, but the symlink ensures compatibility with older versions.

## Step 4: Initialize git and commit

If the current directory is not already a git repository, run `git init`.

Stage and commit:

```bash
git add AGENTS.md CLAUDE.md
git commit -m "Initialize project with AGENTS.md"
```

## Important notes

- Never overwrite existing AGENTS.md or CLAUDE.md
- The CLAUDE.md symlink ensures broadest compatibility across tools
