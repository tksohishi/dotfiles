---
name: x-search
description: Search X (Twitter) via Hermes Agent's `x_search` tool, billed against the user's X Premium subscription quota (no per-call cost). Use when the user runs `/x-search <query>`, or asks to search X / Twitter / Tweets / ツイート for recent posts. Returns post text, URL, date, and author handle. Read-only; does not post.
---

# X Search

Shell out to `hermes -z` to invoke xAI's `x_search` tool, which routes through the user's X Premium OAuth credential. Search-only, no posting. Each call uses the X Premium subscription quota, not a paid API key.

## Usage

User invokes via `/x-search <query>`. `$ARGUMENTS` is the raw query string — pass it through to Hermes with a formatting wrapper.

`$ARGUMENTS` may also be a single X URL (`x.com/<handle>/status/<id>` or `x.com/i/article/<id>`), in which case use the lookup form below instead of the search form. That is the only anonymous way to read an X article: articles are login-walled, and `agent-browser` is not signed in.

## Run

`-t` must come before `-z`. `hermes -z -t x_search "..."` fails with `argument -z/--oneshot: expected one argument`, because argparse refuses a value starting with `-`.

```bash
hermes -t x_search -z "Use the x_search tool to search X for: $ARGUMENTS

Return up to 5 most-relevant recent posts. For each, output:
- Post text in quotes (truncate to ~200 chars with '…' if longer)
- URL
- Date and author handle (e.g. 2026-05-17 by @NousResearch)

Separate posts with a blank line. No commentary or summary." 2>&1
```

### Trending queries

When the query asks what's "trending" (or hot / talked about right now), constrain the window explicitly: add "Only consider posts from the last 6-12 hours." to the prompt. Without it, ranking favors day-old viral posts whose accumulated engagement outscores a story that broke hours ago, so genuinely-current stories get buried.

`-t x_search` restricts the toolset for this invocation regardless of global `hermes tools` config — the call stays on the subscription path even if other toolsets are re-enabled later.

### Single post or article lookup

```bash
hermes -t x_search -z "Use the x_search tool to look up this specific X post: $ARGUMENTS

Return the post's full text verbatim, its author handle, and its date. If it is an article, return the article body. No commentary." 2>&1
```

A post that links to an X article often resolves to the article body rather than the short post text; that is usually what you wanted, but say which one you got.

Output is plain text. Quote it back to the user as-is unless they ask for a different format.

## Caveats

- **Auth check (one-time).** Requires `xai-oauth` credential. If `hermes auth status xai-oauth` does not print `logged in`, ask the user to run `hermes auth add xai-oauth --type oauth` themselves (browser OAuth, can't be scripted). The older `hermes login` subcommand was removed.
- **Subscription tier matters.** OAuth succeeds with any X Premium tier, but `x_search` calls only work if the xAI account behind the OAuth has Grok entitlement (X Premium / Premium+ or SuperGrok). Failure mode: OAuth passes, the call returns a 403 or quota error.
- **`hermes doctor` warning is cosmetic.** It checks for `XAI_API_KEY` env var and shows `⚠ x_search (missing XAI_API_KEY)` even when OAuth is working. Trust the actual call result, not doctor.

## When NOT to use

- Deep multi-step X research — `hermes -z` is one-shot. For follow-ups, suggest the user run `hermes` interactively.
- Non-X web research — use WebSearch / WebFetch. `x_search` queries X posts only.
- Posting / replying / DMs — not supported by `x_search`.
