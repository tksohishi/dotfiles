---
name: create-project-skill
description: Scaffold a project-local Claude skill at .claude/skills/<name>/ and add an inline reference to project AGENTS.md so Codex picks it up via the file it already reads. Use when adding a new project-scoped Claude skill that should also be discoverable to Codex.
---

# create-project-skill

Use when the user wants to add a new project-local Claude skill, especially when Codex (which has no project-local skill support) should discover the same workflow.

## Inputs

Ask for any not provided:
- **Skill name** — kebab-case, no spaces (e.g. `db-migrate`, `lint-fix`).
- **Description** — one sentence; this is what Claude reads to decide when to invoke the skill.
- **Body** — the operational Markdown for the skill. Either supply directly or ask the user to draft.

## Steps

1. Verify cwd is a project root (a git repo or has AGENTS.md / CLAUDE.md / package config).
2. Create `.claude/skills/<name>/SKILL.md` with this exact format:

   ```markdown
   ---
   name: <name>
   description: <description>
   ---
   <body>
   ```

3. Update the project's `AGENTS.md`:
   - If a `## Project Skills` section exists, append a bullet to it.
   - Otherwise, add the section near the top of the file (after the intro paragraph, before tooling-specific sections).
   - Bullet format: `` - **<name>**: <description>. Full instructions: `.claude/skills/<name>/SKILL.md` ``

4. Report:
   - Created path
   - AGENTS.md section that was modified or created
   - Reminder that Codex will see the bullet on next session and `Read` the SKILL.md when it needs the body.

## Edge cases

- `<name>` already exists → ask before overwriting.
- No AGENTS.md → ask whether to create one (use AGENTS.md, not CLAUDE.md, since `AGENTS.md` is the canonical cross-agent name) or skip the reference.
- Project uses `CLAUDE.md` instead of `AGENTS.md` → still write to AGENTS.md if it doesn't exist; the user's convention (per global AGENTS.md) is AGENTS.md as the canonical file with CLAUDE.md as a symlink.

## Why the AGENTS.md reference

Codex has no project-local skill discovery (no `<project>/.codex/skills/`). AGENTS.md is read on every Codex session, so an inline reference makes the skill visible. When Codex needs the full body, it `Read`s the SKILL.md path. Inline (not @-import) — Codex's @-import support is unconfirmed; inline works in all three agents (Claude, Codex, Gemini).
