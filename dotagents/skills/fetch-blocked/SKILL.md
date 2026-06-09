---
name: fetch-blocked
description: Access content on bot-blocked sites (Reddit, X/Twitter, Cloudflare-walled pages) anonymously, without login, via URL rewrites, public endpoints, or agent-browser. Use when WebFetch is denied by the blocked-domains hook, returns 403/429 or a challenge page, or the user asks to read a Reddit thread, a tweet/post URL, or any bot-walled page.
---

# Fetch Blocked Sites

Strategy map for sites that block plain HTTP fetchers. Escalate in order: URL rewrite → public endpoint → agent-browser. Don't start with the browser when a rewrite works.

General heuristic when WebFetch fails on a domain not listed below:

- Media/content sites (news, forums, docs, shops): `http GET <url>` via httpie; if that 403s/500s, retry with a browser User-Agent header. Much of the "blocking" is specific to WebFetch's fetcher, and plain httpie from this residential IP gets through.
- Social or account-required sites (login walls, JS shells): `agent-browser --headed` with login, and only if the content is really needed; don't burn time escalating for low-value pages.

## Other verified sites (2026-06)

| Site | WebFetch | What works |
|---|---|---|
| stackoverflow.com | refused client-side | plain httpie; Stack Exchange API (`api.stackexchange.com/2.3/questions/<id>?site=stackoverflow&filter=withbody`) for structured JSON |
| nytimes.com | refused client-side | plain httpie (paywall still applies to full articles) |
| amazon.com / amazon.co.jp | 500 bot block | httpie with browser UA |
| 5ch.net | 403 | plain httpie |
| quora.com, glassdoor.com | 403 | agent-browser --headed only (403 even to httpie with browser UA) |
| facebook.com, tiktok.com | empty JS/login shell | agent-browser --headed + login; usually not worth it |

## Reddit

WebFetch refuses every reddit domain client-side ("unable to fetch"). Use httpie against `old.reddit.com`:

- HTML (works anonymously): `http GET 'https://old.reddit.com/r/<sub>/top/?t=week'` — server-rendered, pipe through `rg`/`head` to trim.
- Structured: append `.rss` (Atom XML), e.g. `https://old.reddit.com/r/<sub>/top/.rss?t=week` or `https://old.reddit.com/r/<sub>/comments/<id>/.rss` for a thread.
- Do NOT use `.json` — Reddit returns 403 to non-browser clients regardless of User-Agent.

## X / Twitter

- Search → `/x-search` skill.
- Single post (you have the status URL): anonymous syndication endpoint, no login.

  ```bash
  # ID from https://x.com/jack/status/20
  http GET 'https://cdn.syndication.twimg.com/tweet-result?id=20&token=a'
  ```

  Returns JSON: `.text`, `.user.screen_name`, `.created_at`, plus quoted tweet and media if present. As of 2026-06 the `token` param is not validated (any value or absent works); if valid IDs start returning 404, token validation may be back — the formula is `((Number(id)/1e15)*Math.PI).toString(36).replace(/(0+|\.)/g,'')` (float precision loss intentional, matches the official widget). If that also fails, escalate to agent-browser.
- Profiles, threads, replies: `agent-browser --headed` (x.com renders nothing without JS).

## LinkedIn / Instagram

Login-walled. `agent-browser --headed`; for LinkedIn follow the LinkedIn section in global instructions (login flow, `/details/experience/` URLs).

## YouTube

`summarize <url>` (direct access is blocked for agents; see repo instructions).

## Cloudflare-challenged pages ("Just a moment...", 403 with cf headers)

`agent-browser --headed` — the challenge auto-clears in 2-3s headed, never headless.

## Maintenance

The WebFetch deny list with per-domain hints lives in `dotagents/hooks/webfetch-blocked-domains.txt`. When a strategy here changes or a new always-blocked domain is found, update both that file and this map.
