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

- **Start minimal, add reactively.** Only add a rule when you notice the agent making the same mistake twice. The best instruction files are grown over weeks, not generated in one pass.
- **The litmus test for each line:** "Would removing this cause the agent to make mistakes?" If not, cut it.
- **Respect the instruction budget.** LLMs reliably follow ~150-200 total instructions across the entire prompt. Every unnecessary line degrades adherence to the lines that matter.
- **Examples over prose.** Point to canonical files (e.g. "Forms: follow `app/components/DashForm.tsx`") rather than describing patterns.
- **Don't duplicate what tools enforce.** If a linter, formatter, or hook handles it, don't add it here. Deterministic tools are cheaper and more reliable than LLM instructions.
- **Anchor to stable things.** Commands, boundaries, and architectural decisions stay accurate. File-by-file descriptions go stale fast.
- **Repository-specific, not generic.** Tailored instructions yield far better results than generic coding guidance. "Our API handlers follow the pattern in `src/api/UserHandler.ts`" beats "keep files organized."
- **Use progressive disclosure.** The root file should be a concise index. Detailed docs belong in separate files, loaded on demand.

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

<Key entrypoints and how the project is organized. Focus on the mental model and non-obvious structure, especially in monorepos. Point to canonical example files rather than describing patterns.>

## Conventions

<Branch naming, commit message format, PR process, anything a new team member would need to know that isn't self-evident from the code.>

## Boundaries

<"never do" rules: files not to touch, directories to avoid, secrets, migrations, etc.>

## Gotchas

<Non-obvious things that will cause the agent to produce broken code. Required env vars, platform quirks. Only include if they exist.>
```

### What NOT to include

- Generic advice ("write clean code", "follow best practices", "use meaningful variable names")
- Standard language conventions the agent already knows
- Detailed API documentation (link to it instead)
- File-by-file descriptions (the agent can read files)
- Information that changes frequently
- Style rules that a linter/formatter handles
- Task-specific instructions that only apply to certain parts of the codebase (use path-scoped rules instead)

### Size target

Keep it under 150 lines. Instruction-following quality degrades as the file grows; research shows adherence drops uniformly across all instructions, not just the newest ones. Shorter is better. If growing beyond 150 lines, split into separate files.

## Step 3: Create CLAUDE.md symlink

```bash
ln -s AGENTS.md CLAUDE.md
```

AGENTS.md is the cross-agent standard. Claude Code reads CLAUDE.md, so this symlink ensures both files stay in sync. Other tools read AGENTS.md natively.

## Step 4: Initialize git and commit

If the current directory is not already a git repository, run `git init`.

Stage and commit:

```bash
git add AGENTS.md CLAUDE.md
git commit -m "Initialize project with AGENTS.md"
```

## Important notes

- Never overwrite existing AGENTS.md or CLAUDE.md
- The CLAUDE.md symlink is required for Claude Code; without it Claude Code won't read AGENTS.md
- Treat AGENTS.md like code: review, prune, and iterate. If the agent isn't following a rule, the problem is likely in your file (too long, too vague, or buried), not the agent.
