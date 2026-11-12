---
name: later
description: Add ideas and deferred work to a project's tmp/backlog/<scope>.md as one structured line each, or remove a line when its work starts or is dropped. Use when the user runs /later [what], or says to keep something for later, 後でやる, あとで, アイデアとして残して, backlog に入れて, or asks what is on the backlog for an app.
---

# later

The backlog is `tmp/backlog/<scope>.md` under the project root (`git rev-parse --show-toplevel`, else cwd); `tmp/` is globally gitignored. It holds what to do later and why, nothing else: no progress, no figures, no history, no design. Context for an item is re-derived from the code, git and data when it is picked up, because notes written now are stale by then and pull the next session toward a past framing.

Other state has its own home:
- Mid-session state for a fresh session: `/handoff`.
- A decision the user made and its reason, or a ruled-out path: auto memory, `project` type.
- Raw measurements and outputs: `tmp/<scope>/<topic>/`, pointed at with `see:`.

## Scopes and slugs

Every line, data directory and memory about one item shares a slug `<scope>/<topic>`.

- `scope`: a name from the project's scope list, a "Scopes" line in its AGENTS.md giving each name a one-line meaning. Apps and non-app areas alike get a specific name (`ops`, `lib`, `research`); there is no catch-all scope. A project with no list uses the single scope `main`.
- An item goes in the scope where its change lands. One that spans apps goes where the shared change is made, and in no other file. One that changes no code goes where its answer will be used.
- `topic`: 2 to 4 English words, kebab-case, naming the problem, not the fix (`refund-hint`, not `add-refund-parser`).

## Line format

```
- P1 11-12 parallax/refund-hint: <what to do or try>. why: <what it moves>. when: <trigger>. see: tmp/parallax/refund-hint/
```

- Required: `MM-DD` date added, slug, what, `why:`.
- Priority tag: `P0` (important and urgent: do now) or `P1` (important, not urgent), first on the line. No tag means P2. Only the user sets or changes a tag; never add or change one on your own judgment.
- `when:` only when the item cannot start until something happens (a measurement accrues, an event, a user decision). A line with `when:` is waiting; one without is startable.
- `see:` only for a path that exists.
- Language: the user's. About 120 characters in Japanese or 200 in English. A line that needs more is two items or carries detail that belongs in `see:`.
- Order in the file: P0, then P1, then the rest, newest last within each.

## Adding

1. Read the scope's file. Missing: create it with a `# <scope>` title.
2. A line with the same slug or the same intent: rewrite it in place instead of adding another.
3. Keep each file under about 40 lines. Past that, name the line to drop (oldest P2, or one whose `why` no longer holds) and ask before adding.
4. Edit with the Edit tool, one line per edit.

Reply with the line as written and its file, nothing else.

## Removing

When work on an item starts, or the user drops it, delete its line. Never annotate a line with progress or status. If the work stops midway and is to be continued later, write a fresh line with what is left.

## Reading

A session working on one scope reads only that scope's file. `/prioritize` reads all of them, or one when given a scope.
