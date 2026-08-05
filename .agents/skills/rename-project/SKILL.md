---
name: rename-project
description: Rename another project completely — folder, GitHub repo, and all local agent state keyed to its old path or name (Claude Code project dir and memory, ~/.claude.json, Codex trust, mise trust, agent-browser session, in-repo name references). Run from this dotfiles session, never from a session inside the target project. Use when the user asks to rename a project, repo, or project folder.
---

The user wants to rename: $ARGUMENTS

Expected arguments: the path of the project to rename, and the new name (e.g. `~/Work/foo bar`). If either is missing, ask. The new path defaults to the same parent directory as the old one.

Renaming only the folder orphans state that is keyed to the absolute path or folder name. Work through every step below in order; report what was migrated and what was skipped at the end.

## Step 1 — Preflight (do not touch anything yet)

1. Resolve `OLD` (absolute path) and `NEW` (same parent, new name unless the user gave a full path). Verify `OLD` exists and is a directory.
2. Collision checks — refuse and stop if:
   - `NEW` already exists (`mv` would nest the source inside it)
   - the encoded Claude project dir for `NEW` already exists (see Step 4 for the encoding)
3. `git -C OLD status --short` must be clean; if dirty, show the output and get the user's acknowledgment before continuing.
4. Session hazard: any agent session or editor open inside `OLD` keeps the directory inode alive after `mv` and silently recreates old-path state. Ask the user to close all sessions/editors in the target project and confirm before proceeding. Never run this skill from a session whose cwd is inside the target.
5. Confirm the full rename (`OLD` → `NEW`, plus GitHub repo if applicable) with the user before executing anything.
6. mise (order matters — untrust must happen BEFORE the mv): if `OLD` has a mise config (`mise.toml`, `.mise.toml`, or `.config/mise/config.toml`), run `mise trust --untrust <old-config-path>` now.

## Step 2 — Rename the folder

```
mv OLD NEW
```

## Step 3 — GitHub repo

1. `git -C NEW remote -v` — if there is no GitHub remote, skip this step.
2. If the repo name matches the old folder name, confirm with the user, then:
   ```
   gh repo rename <new-name> -y -R <owner>/<old-name>
   ```
   If the repo name differs from the folder name, ask whether it should follow.
3. Verify `git -C NEW remote -v` now shows the new URL. If it is stale, fix it explicitly:
   ```
   git -C NEW remote set-url origin <new-url>
   ```
   Do not rely on GitHub's redirect as the fix.
4. Remind the user this is outward-facing: existing clones and links keep working via redirect, but should be updated.

## Step 4 — Claude Code state

1. Encoded project dir: Claude encodes the absolute path by replacing every non-alphanumeric character (`/`, `.`, spaces, `~`, …) with `-`. Example: `/Users/takeshi/.dotfiles` → `-Users-takeshi--dotfiles`.
   - Compute the encoded names for `OLD` and `NEW`, then list `~/.claude/projects/` and confirm the old encoded dir actually exists — match against the listing, don't guess.
   - Rename it: `mv ~/.claude/projects/<encoded-old> ~/.claude/projects/<encoded-new>`. This carries session transcripts and `memory/` along.
2. `~/.claude.json`: it has a `.projects` object keyed by absolute path. Move the entry with jq:
   ```
   jq '.projects[$new] = .projects[$old] | del(.projects[$old])' --arg old "OLD" --arg new "NEW" ~/.claude.json > tmp && mv tmp ~/.claude.json
   ```
   (Write the temp file in the dotfiles project `tmp/`, then replace.)
3. Known limitation, tell the user: `cwd` embedded inside old session `.jsonl` transcripts and `history.jsonl` stays stale. Memory and new sessions work fine; old sessions may not resume cleanly.

## Step 5 — Codex

1. In `~/.codex/config.toml`, find `[projects."OLD"]` and rewrite the key to `[projects."NEW"]` (Edit the live file; `[projects]` entries are local state, not symlinked).
2. Known limitation, tell the user: Codex thread history (`state_5.sqlite`, rollout files) embeds the old cwd, so pre-rename Codex threads may not resume from the new path. Do not hand-edit the sqlite.

## Step 6 — mise trust (second half)

If Step 1 untrusted a config, trust it at the new location: `mise trust <new-config-path>`. Verify with `mise trust --show` from `NEW`.

## Step 7 — agent-browser

The authoritative reference is the project-local `agent-browser.json` (fields `"session": "<folder-name>"`, `"profile": "./.agent-browser"`); the profile dir moves with the folder.

If `NEW/agent-browser.json` exists:
1. Close the old session first: `agent-browser --session <old-name> close` (ignore errors if no daemon is running).
2. Update the `session` field to the new name; daemon runtime files under `~/.agent-browser/` regenerate on next use.
3. Delete stale `~/.agent-browser/<old-name>.config` / `.pid` / `.sock` / `.log` leftovers.
4. Update session-name mentions in the project's AGENTS.md, if any.

## Step 8 — In-repo name references

Grep `NEW` for the old name and show the match list to the user before editing. Typical spots:
- `package.json` `name` field / `pyproject.toml` `name`
- `README` title
- `AGENTS.md` / `CLAUDE.md`
- `.claude/settings.local.json` (absolute paths in permission rules)
- `.env.example`

Apply the edits the user agrees to. Never read or edit `.env` / `.env.*` (secrets rule); if the grep filename listing shows a hit there, tell the user to update it themselves.

## Step 9 — Verify and report

- `ls NEW` succeeds
- `git -C NEW remote -v` shows the new URL; `gh repo view --json name` (from `NEW`) shows the new name
- `~/.claude/projects/<encoded-new>` exists and `<encoded-old>` is gone
- `jq '.projects | has($p)' --arg p "NEW" ~/.claude.json` is true
- `mise trust --show` from `NEW` is clean (if applicable)

Report a checklist: what was migrated, what was intentionally skipped, and the stated limitations (stale cwd in old Claude transcripts, pre-rename Codex threads).
