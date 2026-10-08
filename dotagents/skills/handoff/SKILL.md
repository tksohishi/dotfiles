---
name: handoff
description: Write a one-shot handoff file (tmp/handoff.md) capturing session state so the user can /clear and continue in a fresh session without losing debugging progress. Use when the user runs /handoff or asks to hand off, wrap up for a fresh session, or preserve state before clearing. Optional argument describes what the next session will focus on.
disable-model-invocation: true
---

# Handoff

Writes `tmp/handoff.md` (project-local `tmp/`, globally gitignored — never the OS temp dir). Loading is not this skill's job: the `handoff-load.sh` SessionStart hook injects the file into the next session started by `/clear` or a fresh launch, trashes it, and tells that session to re-ground, salvage memory and continue.

The reason this exists instead of `/compact`: generic summaries drop exactly the state that makes long debugging arcs expensive to resume — what was already ruled out, and the evidence that ruled it out. Write those sections with the most care.

The handoff is the only place session state goes. Do not also write an "open threads" / "state on <date>" memory: durable facts (a lesson with its evidence, a service quirk, a user decision not in docs) go to topic memories, and everything dated, pending or numeric stays in the handoff, which the load hook deletes.

## Ground everything

Write from verified state, not recollection. Before writing:

- Review the whole session: what was discussed, what the user decided, what was tried and dropped. Decisions made in conversation exist nowhere else.
- Read memory written or changed during this session (project memory dir, newest first) so the handoff points to it instead of restating it, and so a decision already saved there isn't contradicted.
- `git status --short` and `git diff --stat` — actual working-tree state
- `git log --oneline -10` — what this session committed
- The repro/verify command(s) for whatever is in progress, capturing current output verbatim

If the transcript's memory of something conflicts with what these show, the commands win.

## Document structure

```markdown
# Handoff — <one-line topic> (<YYYY-MM-DD HH:MM>)

One-shot handoff: re-ground claims against git/live state before acting on them; if this file is still on disk, trash it (`trash tmp/handoff.md`) after reading.

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

## Language

Write the document in the language the session was mostly conducted in. If the user's prompts were largely Japanese, write the whole handoff in Japanese (headings included; keep the `# Handoff` prefix, commands, paths, and verbatim error output as they are). The next session reads it in the same language the user will continue in. Follow the Japanese conventions in the global instructions (first person 私, no circled numbers, punctuation outside `**`).

## After writing

Tell the user exactly this, in the language the conversation is in (the project's instructions or the user's own words decide it, never this skill's English; a Japanese session gets it in Japanese), substituting nothing else in and keeping the commands as they are:

1. Run `/clear` (or open a new session in this directory)
2. Send any message; the handoff loads automatically

The rest of the turn (the one-line summary of what the handoff covers) is in that language too.

The hook is Claude Code only. In Codex, the file's header still directs a session told to "read the handoff" to re-ground and trash it.
