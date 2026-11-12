---
name: later
description: Keep ideas and deferred work in the project backlog through the `later` CLI (add, list, edit, tag, close), one structured item each. Use when the user runs /later [what], or says to keep something for later, 後でやる, あとで, アイデアとして残して, backlog に入れて, asks what is on the backlog (for an app), or when work on a backlog item starts, ships or is dropped.
---

# later

The backlog lives in `tmp/backlog.db` at the project root and is read and written only through the `later` CLI (`later -h`). Never open the database with sqlite3 or edit it any other way. The user does not read it directly: they add, look and ask through you, so report what you changed.

An item holds what to do later and why, nothing else: no progress, no figures, no history, no design. Context is re-derived from the code, git and data when the item is picked up, because notes written now are stale by then and pull the next session toward a past framing. Other state has its own home:
- Mid-session state for a fresh session: `/handoff`.
- A decision the user made and its reason, or a ruled-out path: auto memory, `project` type.
- Raw measurements and outputs: `tmp/<scope>/<topic>/`, given as `--see`.

## Slugs

Every item, data directory and memory about one thing shares a slug `<scope>/<topic>`.

- `scope`: a name from the project's "Scopes:" line in AGENTS.md (`later scopes` lists them; without the line the only scope is `main`). An item goes in the scope where its change lands; one that spans apps goes where the shared change is made. One that changes no code goes where its answer will be used. When no scope fits, ask the user whether to add one; never stretch an unrelated one.
- `topic`: 1 to 4 English words, kebab-case, naming the problem, not the fix (`refund-hint`, not `add-refund-parser`).

## Adding

```
later add heron/refund-hint --what "<what to do or try>" --why "<what it moves>" [--when "<trigger>"] [--see tmp/heron/refund-hint]
```

- Check first with `later ls <scope>` for an item with the same intent; change that one with `later edit` instead of adding another.
- `--when` only when the item cannot start until something happens (a measurement accrues, an event, a user decision). A target date or "ship with X" is not a trigger: work that can start now has no `--when`.
- `--date YYYY-MM-DD` only when moving an item recorded earlier elsewhere, with the date it was first written down.
- `--tag P0` (important and urgent) or `--tag P1` (important, not urgent) only when the user said so. Untagged means P2. Never set or change a tag on your own judgment; `later tag` is for the user's word.
- Write in the user's language. The CLI rejects text past its width limits; put detail in `--see` rather than squeezing it in.

Reply with the line the CLI printed.

## Closing

When work on an item starts, `later done <slug>`; when the user drops it, `later drop <slug>`. A short `--note` only when it says something a later reader needs (`--note "superseded by lib/feed-retry"`). If work stops midway with something left, add a fresh item for what is left. `later undo <slug>` reopens a mistaken close.

## Reading

`later ls [scope]` for one scope, `--waiting` / `--ready` to split on `when`, `--tag P0` for a tag, `--closed` for what was done or dropped, `--json` for analysis. A session working on one scope lists only that scope. `/prioritize` reads everything.
