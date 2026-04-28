---
name: sync-project-skills
description: Scan <project>/.claude/skills/ and ensure every existing skill has an inline reference in project AGENTS.md (Project Skills section). Use once per project to backfill references for skills created before the AGENTS.md convention, or to reconcile after manual edits. Companion to create-project-skill.
---

# sync-project-skills

Use to bring AGENTS.md in line with `.claude/skills/`. Doesn't create or delete skills — only updates the AGENTS.md references.

## Steps

1. List all `.claude/skills/*/SKILL.md` in the project root.
2. For each, read frontmatter `name` and `description`.
3. Search AGENTS.md for a line referencing `` `.claude/skills/<name>/SKILL.md` ``.
4. If absent, queue an "add" action with the bullet:
   `` - **<name>**: <description>. Full instructions: `.claude/skills/<name>/SKILL.md` ``
5. If `## Project Skills` section doesn't exist, create it (after intro paragraph, before tooling-specific sections).
6. Apply queued additions in alphabetical order under that section.
7. Report:
   - **Added** — skills newly referenced.
   - **Already-present** — count of skills already correctly referenced.
   - **Dangling** — AGENTS.md bullets pointing to nonexistent SKILL.md files. Flag for user review; do not auto-remove.

## Edge cases

- AGENTS.md doesn't exist → ask whether to create one.
- Skill description in SKILL.md differs from the existing AGENTS.md bullet → flag and ask which is canonical (don't silently overwrite either side).
- `.claude/skills/` doesn't exist or is empty → no work; report.

## Why

Codex has no project-local skill discovery (no `<project>/.codex/skills/`). AGENTS.md is read on every Codex session, so an inline reference makes the skill visible. This skill keeps that bridge accurate when skills are added, renamed, or removed without going through `create-project-skill`.
