---
name: keepalive
description: Keep the current session's prompt cache warm while the user steps away, by scheduling minimal pings on a 50-minute interval with a hard deadline. Use when the user runs /keepalive [duration|until HH:MM], or says "keep the session alive", "keep the cache warm", "I'll be back in N hours". Claude Code only (uses /loop); refuse while the user is on usage credits.
---

Cache economics: a ping re-reads the cached prefix at the cache-read price and refreshes the 1-hour TTL; letting it expire costs a full cache write on the next real message (80x a read on Fable 5.1, 20x on Fable 5). Worth it only when the user will actually come back, and only on the 1-hour TTL.

## Before scheduling

1. Ask once: "Are you on usage credits right now (weekly bar exhausted)?" Usage credits drop the TTL to 5 minutes, so every ping becomes a full rewrite. If yes, stop and say so; don't schedule.
2. Parse the argument into an absolute local deadline (`date +%H:%M` is in the UserPromptSubmit hook context). Accepted forms: `2h`, `90m`, `until 14:00`. Default 2h. Cap at 8h; if the request exceeds it, clamp and say so.
3. State the deadline and the interval, then schedule.

## Schedule

Invoke the `loop` skill with a 50-minute interval (not 55: the TTL clock starts at the request's start, and scheduler drift or a slow response pushes 55 past the hour). The loop prompt, with the deadline filled in:

```
keepalive ping. Deadline <HH:MM local>. If the current local time is past the deadline, or the user has sent any message since this loop started, stop this loop (CronDelete) and say "keepalive stopped". Otherwise reply with exactly "ok". No tools, no analysis.
```

## Stopping

- The user's first real message means they're back and refreshing the cache themselves: stop the loop in that turn, even if they don't mention it.
- `/keepalive stop` stops it immediately.
- Never extend past the deadline on your own; the user re-runs the skill if they need more.

## Report

One line on scheduling: "Keeping cache warm every 50m until HH:MM. Any message from you stops it." Nothing else.
