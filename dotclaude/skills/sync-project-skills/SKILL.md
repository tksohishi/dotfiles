---
name: sync-project-skills
description: Migrate a project's skills to the cross-agent layout — move each .claude/skills/<name>/ real directory into .agents/skills/<name>/ and replace it with a symlink, so both Codex (native .agents discovery) and Claude Code (the .claude symlink) find them. Also reconciles already-migrated skills. Companion to create-project-skill.
---

# sync-project-skills

Bring a project's skills to the canonical layout below. Companion to `create-project-skill`; safe to run repeatedly (idempotent).

## Target layout

- Canonical: `.agents/skills/<name>/SKILL.md` — a real directory; Codex reads it natively.
- Bridge: `.claude/skills/<name>` → `../../.agents/skills/<name>` — a relative symlink; Claude Code discovers the skill through it.

## Steps

1. List entries in `.claude/skills/` and `.agents/skills/`.
2. For each skill name, classify and act:
   - **Real dir in `.claude/skills/<name>`, absent from `.agents/`** → migrate it. `mkdir -p .agents/skills`, then `git mv .claude/skills/<name> .agents/skills/<name>` (plain `mv` if not a git repo), then `ln -s ../../.agents/skills/<name> .claude/skills/<name>`.
   - **`.claude/skills/<name>` already a symlink to `../../.agents/skills/<name>`** with the `.agents/` dir present → already canonical; skip.
   - **Real dir in `.agents/skills/<name>`, nothing in `.claude/`** → add the bridge symlink only.
   - **Real dir in BOTH** → conflict; show both and ask which is canonical. Don't auto-merge or auto-delete.
   - **`.claude/skills/<name>` is a symlink whose target is missing** → flag for user review.
3. Always use the relative symlink target `../../.agents/skills/<name>` so links survive clone/move.
4. Prune the dead AGENTS.md bridge: for each migrated/canonical skill, remove its bullet from the `## Project Skills` section (lines pointing at `.claude/skills/<name>/SKILL.md` or the skill `name`). If the section is left empty, remove the heading too. This bridge existed only because Codex couldn't discover project skills; Codex now reads `.agents/skills/` natively, so the bullets are redundant. Only remove bullets that correspond to skills you migrated/confirmed this run — leave unrelated content untouched.
5. Report:
   - **Migrated** — moved from `.claude/` to `.agents/` and symlinked.
   - **Symlinked** — only needed the `.claude/` bridge added.
   - **Already-canonical** — count skipped.
   - **Pruned** — AGENTS.md bullets/section removed.
   - **Conflicts / broken** — flagged for user review; not auto-fixed.

## Edge cases

- Neither `.claude/skills/` nor `.agents/skills/` exists → no work; report.
- Not a git repo → use `mv` instead of `git mv`.
- A skill listed in AGENTS.md but not present in `.claude/`/`.agents/` (dangling bridge bullet) → flag it; don't prune, since it may point at a skill that lives elsewhere (e.g. a Claude-only global skill exposed to Codex only via this listing).

## Why

Codex now discovers `.agents/skills/` natively (scans cwd up to repo root), so the old AGENTS.md inline-reference bridge is obsolete for discovery. `.agents/` is the agent-neutral canonical location (same convention as AGENTS.md). Claude Code only scans `.claude/skills/`, but follows a per-skill directory symlink placed there — verified by the global skills.sh skills (e.g. `~/.claude/skills/docx -> ../../.agents/skills/docx`), which load via exactly this layout.
