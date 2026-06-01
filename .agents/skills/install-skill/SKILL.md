---
name: install-skill
description: Discover and install an agent skill via bunx skills add -g, then track it in dotagents/skills.txt for new-machine reproducibility
---

The user wants to install a skill, given: $ARGUMENTS

First, classify the input form:
- Looks like `<owner>/<repo>` or `<owner>/<repo>:<skill>` (e.g. `anthropics/skills:pdf`) → skip discovery, go to install.
- Looks like a description of a need (e.g. "review terraform diffs", "extract text from PDFs") → run discovery first.

---

## Path A: Discover (input is a description)

1. Invoke the `find-skills` skill via the Skill tool, passing `$ARGUMENTS` as the query.
2. find-skills searches skills.sh and returns ranked candidates. Surface up to 3 to the user with:
   - Skill name and source (`<owner>/<repo>`)
   - One-line description (from frontmatter)
   - Install count or trust signal if visible
3. Wait for the user to pick one — or say none fit. If they pick, capture as `<owner>/<repo>:<skill>`.

## Path B: Direct (input is `<owner>/<repo>[:<skill>]`)

Skip to install.

---

## Install

1. Run the install:
   - Single skill: `bunx skills add -g <owner>/<repo> --skill <skill>`
   - Whole repo (no `:<skill>`): `bunx skills add -g <owner>/<repo>`
2. Surface bunx's security risk scan output to the user (Gen / Socket / Snyk ratings appear at install time). Don't block on a Medium rating; just report.
3. Verify:
   - `~/.agents/skills/<skill>/` exists (canonical content)
   - `~/.claude/skills/<skill>/` resolves and contains the same files (symlink works)
   - If the symlink is broken, something is wrong with `~/.claude/skills/` — it must be a real directory, not a symlink. See install.sh commit d3e172f for the per-skill symlink pattern.

## Track

1. Read `~/.dotfiles/dotagents/skills.txt`.
2. Append the new entry in alphabetical order (compare full `<owner>/<repo>:<skill>` string). Skip if already present.
3. Format: `<owner>/<repo>:<skill>` for single, `<owner>/<repo>` for whole-repo.

## Commit and push

1. `git add dotagents/skills.txt`
2. Commit message: `Add <skill> to skills.txt`
3. `git push origin main`

---

## Notes

- `find-skills` itself must be installed (`vercel-labs/skills:find-skills`). If invoking it errors out with "skill not found", install it first using this same skill in Path B mode (`/install-skill vercel-labs/skills:find-skills`), then retry the original request.
- Skip risk evaluation beyond what bunx already prints. The user reads the Gen / Socket / Snyk ratings and decides.
- This skill is the canonical path for installing skills in the dotfiles workflow. Raw `bunx skills add -g ...` works but leaves `skills.txt` out of date, breaking install.sh replay on new machines.
