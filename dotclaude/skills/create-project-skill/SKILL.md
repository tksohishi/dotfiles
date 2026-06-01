---
name: create-project-skill
description: Scaffold a project-local skill at .agents/skills/<name>/ (the cross-agent canonical location) and symlink it into .claude/skills/<name> so both Codex (native .agents discovery) and Claude Code (the symlink) find it. Use when adding a new project-scoped skill.
---

# create-project-skill

Use when the user wants to add a new project-local skill. The canonical copy lives in `.agents/skills/` (the agent-neutral location, same idea as AGENTS.md). Codex reads it natively; a per-skill directory symlink in `.claude/skills/` lets Claude Code discover the same skill.

## Inputs

Ask for any not provided:
- **Skill name** — kebab-case, no spaces (e.g. `db-migrate`, `lint-fix`).
- **Description** — one sentence; this is what the agent reads to decide when to invoke the skill.
- **Body** — the operational Markdown for the skill. Either supply directly or ask the user to draft.

## Steps

1. Verify cwd is a project root (a git repo or has AGENTS.md / CLAUDE.md / package config).
2. Check for old-convention skills: scan `.claude/skills/` for entries that are *real directories* (not symlinks into `.agents/`). If any exist, notify the user up front — these predate the `.agents/` canonical layout and aren't visible to Codex. Recommend running `sync-project-skills` to migrate them. Don't auto-migrate; just surface the list and continue.
3. Create the canonical skill at `.agents/skills/<name>/SKILL.md` with this exact format:

   ```markdown
   ---
   name: <name>
   description: <description>
   ---
   <body>
   ```

4. Symlink it into `.claude/skills/` so Claude Code discovers it. Use a **relative** target so the link survives the repo being cloned or moved:

   ```
   mkdir -p .claude/skills
   ln -s ../../.agents/skills/<name> .claude/skills/<name>
   ```

5. Report:
   - Canonical path created (`.agents/skills/<name>/SKILL.md`) and the symlink created (`.claude/skills/<name>`).
   - That Codex discovers `.agents/skills/` natively (scans cwd up to repo root) and Claude Code discovers the skill via the `.claude/skills/` symlink.

## Edge cases

- `<name>` already exists in either location → ask before overwriting.
- `.claude/skills/<name>` exists as a *real* directory (old convention) → don't overwrite; run `sync-project-skills` to migrate it to `.agents/` and replace it with the symlink.
- Neither `.agents/` nor `.claude/` exists → create the dirs as needed.

## Why .agents/ is canonical

`.agents/skills/` is the agent-neutral location (same convention as AGENTS.md): Codex scans it natively from cwd up to the repo root, and skills.sh installs there too. Claude Code only scans `.claude/skills/`, but it follows a per-skill *directory* symlink placed there. This is verified by the global skills.sh skills (e.g. `~/.claude/skills/docx -> ../../.agents/skills/docx`), which load via exactly this layout. One source of truth in `.agents/`, one symlink for Claude.

No AGENTS.md inline reference is needed anymore: Codex discovers project skills natively, so the old bridge (an AGENTS.md bullet pointing at the SKILL.md) is obsolete.
