---
name: fetch-blocked
description: Access content on bot-blocked sites (Reddit, X/Twitter, Cloudflare-walled pages) anonymously, without login, via URL rewrites, public endpoints, or agent-browser. Use when WebFetch is denied by the blocked-domains hook, returns 403/429 or a challenge page, or the user asks to read a Reddit thread, a tweet/post URL, or any bot-walled page.
---

# Fetch Blocked Sites

Strategy map for sites that block plain HTTP fetchers. Escalate in order: URL rewrite → public endpoint → agent-browser. Don't start with the browser when a rewrite works.

**Every `http`/`https` (httpie) call below needs `--ignore-stdin`** (flags after the URL). Without it httpie blocks reading stdin in the Bash tool (no TTY/EOF): the command hangs, gets auto-backgrounded, then fails with exit 144 and a 0-byte body. Add `--follow` for endpoints that 302 to an empty body (e.g. Naver).

General heuristic when WebFetch fails on a domain not listed below:

- Media/content sites (news, forums, docs, shops): `http GET <url> --ignore-stdin` via httpie; if that 403s/500s, retry with a browser User-Agent header. Much of the "blocking" is specific to WebFetch's fetcher, and plain httpie from this residential IP gets through.
- Social or account-required sites (login walls, JS shells): `agent-browser --headed` with login, and only if the content is really needed; don't burn time escalating for low-value pages.

## Other verified sites (2026-06)

| Site | WebFetch | What works |
|---|---|---|
| stackoverflow.com | refused client-side | plain httpie; Stack Exchange API (`api.stackexchange.com/2.3/questions/<id>?site=stackoverflow&filter=withbody`) for structured JSON |
| nytimes.com | refused client-side | plain httpie (paywall still applies to full articles) |
| amazon.com / amazon.co.jp | 500 bot block | httpie with browser UA |
| naver.com | refused client-side | plain httpie + `--ignore-stdin --follow` (else 302s to an empty body); server-rendered, browser UA not needed. Only some titles expose a rating: grep ``"key":"평점"..."text":"NN/100"`` (out of 100) |
| imdb.com | empty (WAF challenge) | GraphQL endpoint for star rating; suggestion endpoint for IDs — see IMDb section |
| 5ch.net | 403 | plain httpie |
| zillow.com | 403 | plain httpie, no UA needed — see Zillow section (headless browser gets PerimeterX Press & Hold) |
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

## IMDb

Title/search pages return an AWS WAF challenge (HTTP 202, `x-amzn-waf-action: challenge`, empty body); a browser User-Agent doesn't help. Use the JSON APIs below instead of fetching the page.

- Star rating (no WAF, anonymous): the public GraphQL caching endpoint returns `aggregateRating` (e.g. 9.3) and `voteCount` for any title ID, movie or TV.

  ```bash
  http POST 'https://caching.graphql.imdb.com/' Content-Type:application/json --ignore-stdin \
    --raw='{"query":"query{title(id:\"tt0111161\"){titleText{text} ratingsSummary{aggregateRating voteCount}}}"}'
  # → .data.title.ratingsSummary.aggregateRating
  ```

- Title ID from a name: the suggestion endpoint returns matches (id, title, year, type, top cast, poster — no rating).

  ```bash
  http GET 'https://v3.sg.media-imdb.com/suggestion/x/shawshank.json?includeVideos=0'   # search by name
  http GET 'https://v2.sg.media-imdb.com/suggestion/t/tt0111161.json'                    # by title ID
  ```

  Chain them: suggestion to resolve name → ID, then GraphQL for the rating.

- Full title page (plot, full cast): `agent-browser --headed` — the WAF challenge is a JS challenge that clears headed, same as the Cloudflare case below.

## Zillow

WebFetch 403s and headless browsers (agent-browser, headless Playwright) get a PerimeterX "Press & Hold" denial that never auto-clears. But plain httpie from this residential IP gets the full server-rendered page, no browser UA needed (verified 2026-07):

- Property page (Zestimate, Rent Zestimate, specs): `http GET 'https://www.zillow.com/homedetails/<slug>/<zpid>_zpid/' --ignore-stdin`
- Rental/for-sale search results (asking prices, addresses): `http GET 'https://www.zillow.com/<city-state-zip>/rentals/' --ignore-stdin`

All data is JSON embedded in `__NEXT_DATA__`, but escaped (string-in-string), so quotes carry backslashes. Grep with patterns that tolerate `\"`:

```bash
rg -o '"zestimate\\?":[0-9]+|"rentZestimate\\?":[0-9]+' page.html | sort -u   # homedetails
rg -o '"price":"\$[0-9,]+' page.html                                          # search results
```

Body is ~300-650KB — always save to a file and `rg`, never cat. PX rate-limits per-IP: ~15+ fetches in one day flipped this IP to captcha-blocked mid-session (observed 2026-07; cleared within a few hours, and a headed patchright Chrome got through even while blocked). When that happens, switch to trulia.com or redfin.com first (same MLS data, see table below) before escalating to a headed real-Chrome via patchright (`chromium.launch({channel: 'chrome-canary', headless: false})`, read `body` text after ~4s); headless never works, and headed agent-browser is unverified (Press & Hold needs a real interaction, unlike Cloudflare's auto-clear).

### Other rental / real-estate listing sites (verified 2026-07)

| Site | WebFetch | What works |
|---|---|---|
| trulia.com | 403 | plain httpie (Zillow-owned, same data; ~1.4MB bodies) |
| redfin.com | 403 | httpie with browser UA (plain httpie 403s) |
| zumper.com, craigslist (`sfbay.craigslist.org/search/apa`) | untested | plain httpie; craigslist bodies are small (~50KB), nicest to grep |
| apartmentlist.com | untested | plain httpie on city pages (`/ca/san-francisco`); neighborhood URL guesses often 404 |
| apartments.com | 403 | nothing — 403 even to httpie with browser UA (quora/glassdoor class); agent-browser --headed only |
| hotpads.com | untested | nothing anonymous — 200 but empty JS shell |

## LinkedIn / Instagram

Login-walled. `agent-browser --headed`; for LinkedIn follow the LinkedIn section in global instructions (login flow, `/details/experience/` URLs).

## YouTube

`summarize <url>` (direct access is blocked for agents; see repo instructions).

## Cloudflare-challenged pages ("Just a moment...", 403 with cf headers)

`agent-browser --headed` — the challenge auto-clears in 2-3s headed, never headless.

## Maintenance

The WebFetch deny list with per-domain hints lives in `dotagents/hooks/webfetch-blocked-domains.txt`. When a strategy here changes or a new always-blocked domain is found, update both that file and this map.
