---
name: handoff
description: Write a one-shot handoff file (tmp/handoff.md) capturing session state so the user can /clear and continue in a fresh session without losing debugging progress. Use when the user runs /handoff or asks to hand off, wrap up for a fresh session, or preserve state before clearing. `/handoff resume` ingests and deletes an existing handoff instead. Optional argument (other than "resume") describes what the next session will focus on.
disable-model-invocation: true
---

# Handoff

Two modes: **write** (default) creates `tmp/handoff.md`; **resume** (argument is `resume`) ingests and deletes it. Writing goes to project-local `tmp/` (globally gitignored — never the OS temp dir).

## Resume mode (`/handoff resume`)

1. Read `tmp/handoff.md`. If absent, say so and stop.
2. Re-ground before acting — the file is point-in-time, not live state. Check `git log`/`git status` since the file's mtime and re-run any verify commands it lists. Anything it calls open or broken may since be done; fresh evidence wins over the file, always.
3. Salvage: any still-true fact future sessions can't derive (from code, git, or existing memory) goes to project memory now.
4. Delete the file (`trash tmp/handoff.md`) — before starting the work, not after, so an interrupted session can't leave it behind.
5. Continue with the handoff's next step, corrected by what re-grounding found.

## Write mode

The reason this exists instead of `/compact`: generic summaries drop exactly the state that makes long debugging arcs expensive to resume — what was already ruled out, and the evidence that ruled it out. Write those sections with the most care.

## Ground everything

Write from verified state, not recollection. Before writing, run:

- `git status --short` and `git diff --stat` — actual working-tree state
- `git log --oneline -5` — where history stands
- The repro/verify command(s) for whatever is in progress, capturing current output verbatim

If the transcript's memory of something conflicts with what these show, the commands win.

## Document structure

```markdown
# Handoff — <one-line topic> (<YYYY-MM-DD HH:MM>)

One-shot handoff: re-ground claims against git/live state, then trash this file (`trash tmp/handoff.md`).

## Goal
What the overall task is and what "done" looks like.

## Current state
Verified working-tree state (from git status/diff), what works, what is
confirmed broken. Note uncommitted changes explicitly.

## Ruled out
Each hypothesis already tried, with the evidence that killed it —
verbatim error messages, not paraphrases. This is the section whose loss
makes a fresh session re-try dead ends; be exhaustive here.

## Repro / verify
Exact commands to reproduce the problem or verify progress, with their
current output.

## Next step
The single concrete next action, plus any decisions the user already made
that constrain it.

## Pointers
Related artifacts by path or URL (plan files, issues, PRs, design docs).
Reference, don't duplicate — content already captured elsewhere stays there.
```

Omit sections that genuinely don't apply (e.g. "Ruled out" for a non-debugging handoff), but never thin out "Ruled out" when it does apply.

If the user passed an argument, treat it as what the next session will focus on and tailor the document accordingly — lead with the state relevant to that focus.

Redact secrets (API keys, tokens, passwords) — the file is plaintext on disk.

## After writing

Tell the user exactly this, substituting nothing else in:

1. Run `/clear` (or open a new session in this directory)
2. Start it with: `/handoff resume`

Resume mode re-grounds the handoff's claims, salvages durable facts to memory, and trashes the file. If the user starts with a plain "read the handoff" instead, the file's self-destruct header still directs the receiving session to trash it after ingesting.
