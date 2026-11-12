---
name: later
description: Add ideas and deferred work to a project's tmp/backlog.md as one structured line each, or remove a line when its work starts or is dropped. Use when the user runs /later [what], or says to keep something for later, 後でやる, あとで, アイデアとして残して, backlog に入れて, or asks what is on the backlog for an app.
---

# later

The backlog is `tmp/backlog.md` at the project root (`git rev-parse --show-toplevel`, else cwd). `tmp/` is globally gitignored. It holds what to do later and why, nothing else: no progress, no figures, no history, no design. Context for an item is re-derived from the code, git and data when it is picked up, because notes written now are stale by then and pull the next session toward a past framing.

Other state has its own home:
- Mid-session state for a fresh session: `/handoff`.
- A decision the user made and its reason, or a ruled-out path: auto memory, `project` type.
- Raw measurements and outputs: `tmp/<scope>/<topic>/`, pointed at with `see:`.

## Slugs

Every line, data directory and memory about one item shares a slug `<scope>/<topic>`.

- `scope`: an app or area name from the project's scope list (a "Scopes" line in its AGENTS.md). If the project has none, use the top-level unit the code is split by (`apps/<name>`, a `scripts/<area>`), and suggest adding the list to AGENTS.md once.
- `topic`: 2 to 4 English words, kebab-case, naming the problem, not the fix (`refund-hint`, not `add-refund-parser`).

## Line format

The file has one `## <scope>` heading per scope, scopes in alphabetical order. Under it, one line per item:

```
- 11-12 parallax/refund-hint: <what to do or try>. why: <what it moves>. when: <trigger>. see: tmp/parallax/refund-hint/
```

- Required: `MM-DD` date added, slug, what, `why:`.
- `when:` only when the item cannot start until something happens (a measurement accrues, an event, a user decision). A line with `when:` is waiting; one without is startable.
- `see:` only for a path that exists.
- A leading `!` (`- ! 11-12 ...`) only when the user said it matters most. Never add it on your own judgment.
- Language: the user's. About 120 characters in Japanese or 200 in English. A line that needs more is two items or carries detail that belongs in `see:`.

## Adding

1. Read only the target scope's section (`rg -n` the heading, then that range).
2. A line with the same slug or the same intent: rewrite it in place with Edit instead of adding another.
3. Keep the file under about 80 lines. Past that, name the line to drop (oldest, or one whose `why` no longer holds) and ask before adding.
4. Edit with the Edit tool, one line per edit.

Reply with the line as written, nothing else.

## Removing

When work on an item starts, or the user drops it, delete its line. Never annotate a line with progress or status. If the work stops midway and is to be continued later, write a fresh line with what is left.

## Reading

A session working on one scope reads only that section. `/prioritize` reads the whole file.
