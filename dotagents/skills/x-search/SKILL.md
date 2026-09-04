---
name: x-search
description: Search X (Twitter) via `x-search`, a thin wrapper over xAI's Responses API `x_search` tool authenticated with the Hermes-held X Premium OAuth token (subscription quota, no per-call cost, ~5s per query). Use when the user runs `/x-search <query>`, or asks to search X / Twitter / Tweets / ツイート for recent posts, or pastes an x.com post/article URL to read. Returns post text, URL, date, and author handle. Read-only; does not post.
---

# X Search

Run `x-search` (in `~/.dotfiles/bin/`, on PATH). It posts straight to `api.x.ai/v1/responses` with the `x_search` server-side tool and prints the model's plain-text answer. Hermes Agent is only the credential holder: the script asks Hermes's Python for the xai-oauth access token, which refreshes it when near expiry. No Hermes agent loop runs, so a query takes seconds, not minutes.

## Usage

`/x-search <query>`: pass `$ARGUMENTS` through as the query words.

```bash
x-search $ARGUMENTS
```

If `$ARGUMENTS` is a single X URL (`x.com/<handle>/status/<id>` or `x.com/i/article/<id>`), the script switches to lookup mode and returns the post's full text, handle, and date, or the article body. Articles are login-walled, so lookup mode is the way to read one unless the project has a signed-in `agent-browser` session. A post that links to an article often resolves to the article body rather than the short post text; say which one you got.

## Budget

Each query draws on the subscription's Grok quota and fires up to ~10 server-side `x_search` calls, so the limit arrives after a handful of narrow queries. Treat `x-search` as discovery: one broad query per topic with `--limit` raised, not several narrow ones. Once you know the accounts or posts, read details (profile, thread, replies, links) with `agent-browser` if the project's AGENTS.md or memory says it holds an X session; otherwise use lookup mode on the specific URL. `x-search --usage` prints the last 7 days of calls from the ledger at `~/.cache/x-search/usage.jsonl`; check it before a fan-out of more than two queries.

Output is plain text. Quote it back to the user as-is unless they ask for a different format.

## Options

Map the user's phrasing onto flags instead of stuffing constraints into the query:

- `--hours N`: use for "trending" / "what's hot right now" queries (6 or 12). Without it, ranking favors day-old viral posts that outscore a story that broke hours ago.
- `--since YYYY-MM-DD` / `--until YYYY-MM-DD`: explicit date window. Date-only format; the API ignored full ISO timestamps in testing.
- `--handles a,b,c`: only posts from named accounts (max 20). Also turns off the default 5,000+ follower filter.
- `--any`: turn off the follower filter without naming handles.
- `--limit N`: posts to return (default 5).
- `--model M`: default `grok-4.20-0309-non-reasoning`. Reasoning models return the same posts about 10x slower; don't switch unless the user asks.
- `--json`: raw API response, for debugging.

## Caveats

- **Auth (one-time).** Requires the Hermes `xai-oauth` credential. If the script fails with an auth error, ask the user to run `hermes auth add xai-oauth --type oauth` themselves (browser OAuth, can't be scripted). OAuth succeeds with any X Premium tier, but `x_search` only works if the account has Grok entitlement (Premium / Premium+ / SuperGrok); the failure mode is a 403 or quota error.
- **Unofficial path.** The token is issued to Hermes's OAuth client; calling api.x.ai with it directly is not a documented xAI feature. If xAI or Hermes changes the client or token storage, fall back to `hermes -t x_search -z "<prompt>"` (slow but supported) and report it.
- **Quota.** Draws on the subscription's Grok quota, shared with the Grok app. The limit is not published; the ledger (`--usage`) is how it gets sized.
- **`hermes doctor` warning is cosmetic.** It checks for `XAI_API_KEY` and warns even when OAuth works. Trust the actual call result.

## When NOT to use

- Non-X web research — use WebSearch / WebFetch. `x_search` queries X posts only.
- Posting / replying / DMs — not supported.
