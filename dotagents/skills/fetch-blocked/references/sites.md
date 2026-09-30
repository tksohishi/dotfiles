# Site map: verified access paths per host

Public map of general platforms. Personal and one-off hosts live in the gitignored `sites.local.md` next to this file; look a host up in both with `rg -i '<host>' references/sites*.md` from the skill directory and read only the matching section or row. Dates are when the path was last verified. Ladder, diagnosis rules, and the patchright-fetch runner live in SKILL.md.

## Rate-limited API endpoints

A 429 from a JSON API after a burst of calls is a quota, not a bot wall: do not climb the ladder. Pause, retry one known-good call with the same method; a 200 confirms the rate limit. Then pace calls, batch where the API allows, or switch to a source without the quota (an RPC for chain data). A 429 on the very first call, or one that comes with a challenge page, is a wall; walk the ladder.

| Endpoint | Limit observed | What works |
|---|---|---|
| api.geckoterminal.com | free tier, about 30 requests/min | plain httpie 200; pace calls (2026-09-06) |
| eth.blockscout.com `/api/v2` | 429 during a burst of log queries | plain httpie `GET /api/v2/addresses/<addr>` 200 after a pause; use an archive RPC for wide log ranges; WebFetch untested (2026-09-23) |
| core-api.prod.blur.io (Blur API) | Cloudflare challenge: httpie 403 | `agent-browser --headed open .../v1/collections/<slug>` clears it and returns the JSON (floor, volume); agent-browser headless, WebFetch and patchright untested (2026-09-29) |

## General sites

| Site | WebFetch | What works |
|---|---|---|
| medium.com (articles) | 403 | httpie with browser UA, 200 (2026-09-10). Server-rendered: article body is in the HTML (172KB), `<title>` is just "Medium" so don't use the title as the liveness check; strip tags and grep for a phrase from the article |
| stackoverflow.com | refused client-side | plain httpie; Stack Exchange API (`api.stackexchange.com/2.3/questions/<id>?site=stackoverflow&filter=withbody`) for structured JSON |
| nytimes.com | refused client-side | plain httpie (paywall still applies to full articles) |
| amazon.com / amazon.co.jp | 500 bot block | httpie with browser UA — see Amazon section below (price gotchas) |
| naver.com | refused client-side | plain httpie + `--ignore-stdin --follow` (else 302s to an empty body); server-rendered, browser UA not needed. Only some titles expose a rating: grep ``"key":"평점"..."text":"NN/100"`` (out of 100) |
| imdb.com | empty (WAF challenge) | GraphQL endpoint for star rating; suggestion endpoint for IDs — see IMDb section below |
| 5ch.net | 403 | plain httpie |
| quora.com | 403 | agent-browser --headed only (403 even to httpie with browser UA) |
| facebook.com, tiktok.com | empty JS/login shell | agent-browser --headed + login; usually not worth it |

## Reddit

Try ordinary HTTPie against `www.reddit.com` RSS first. A visible browser is not required when the endpoint returns Atom XML.

- Thread comments: `http GET 'https://www.reddit.com/r/<sub>/comments/<id>/.rss' --ignore-stdin --follow --body`.
- Listings and search: `https://www.reddit.com/r/<sub>/top/.rss?t=week` and `https://www.reddit.com/r/<sub>/search.rss?q=<q>&restrict_sr=1&sort=new`. Check the response body for actual feed entries; HTTP 200 alone can be a login or block page.
- If the www RSS response is blocked or a login shell, try the corresponding `old.reddit.com` RSS URL. Failure on old does not imply failure on www: ordinary HTTPie returned Atom XML for www while old returned “Welcome to Reddit” HTML for the same thread (verified 2026-09-04).
- WebFetch and direct `.json` requests have returned access errors. Do not infer RSS availability from those results.
- If both RSS hosts fail, consult the skill's browser escalation and CAPTCHA stop rules. Headed `patchright-fetch` against www has retrieved RSS; headless patchright has encountered a network-security block. These observations do not establish that all Reddit RSS requires headed mode. Use isolated browser profiles, never the user's personal Chrome session. Mirrors and search engines are not an escalation rung.

## X / Twitter

- Search → `/x-search` skill.
- Single post (you have the status URL): anonymous syndication endpoint, no login.

  Returns the post text only. A post that links to an X article gives you the `t.co` link, not the article body — see the article row below.

  ```bash
  # ID from https://x.com/jack/status/20
  http GET 'https://cdn.syndication.twimg.com/tweet-result?id=20&token=a'
  ```

  Returns JSON: `.text`, `.user.screen_name`, `.created_at`, plus quoted tweet and media if present. As of 2026-06 the `token` param is not validated (any value or absent works); if valid IDs start returning 404, token validation may be back — the formula is `((Number(id)/1e15)*Math.PI).toString(36).replace(/(0+|\.)/g,'')` (float precision loss intentional, matches the official widget). If that also fails, escalate to agent-browser.
- X articles (`x.com/i/article/<id>`, what a `t.co` on a long post usually expands to): login-walled. httpie returns a ~260KB JS shell with no article text, and `agent-browser --headed` redirects to `/i/jf/onboarding/web?...mode=login` — the browser profile is not signed in to X, and signing it in is not worth it. Use `/x-search` and pass the post or article URL as the query; x_search resolves it through the user's X Premium credential and returns the article body (verified 2026-07).
- Profiles, threads, replies: `agent-browser --headed` (x.com renders nothing without JS). Profiles do render logged out — `open https://x.com/<handle>` then `get text body` gives bio plus recent posts (verified 2026-07).
- Profile timeline via the syndication host (`syndication.twitter.com/srv/timeline-profile/screen-name/<handle>`): HTTP 429 from httpie on the first request (2026-09-25), not a usable rung; a profile read goes through `agent-browser --headed` as above.

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

- Full title page (plot, full cast): `agent-browser --headed` — the WAF challenge is a JS challenge that clears headed, same as the Cloudflare case in SKILL.md.

## Amazon (amazon.co.jp / amazon.com)

WebFetch gets a 500 bot block (hook-denied). httpie with a browser UA returns a 200 server-rendered product page (verified 2026-07):

```bash
http GET 'https://www.amazon.co.jp/dp/<ASIN>' --ignore-stdin --follow \
  'User-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36' \
  'Accept-Language:ja-JP,ja;q=0.9' -o tmp/amz.html
grep -oE '<title>[^<]*' tmp/amz.html   # full product name incl. feature claims — reliable
```

Gotchas:

- **Titles are reliable, prices are not.** Amazon serves varying bot-degraded page variants per fetch; price markup (`a-price-whole`, `a-offscreen`) is often missing or fragmentary, and a `￥[0-9,]+` grep can hit comparison-widget / other-seller prices instead of the buybox. Treat any extracted price as approximate and say so.
- **agent-browser headless anonymous gets the export view**: English title, USD prices (e.g. `.a-price .a-offscreen` → `USD26.29`). Fine for confirming an ASIN exists and what it is; wrong for JP prices. For an exact JP price, use `agent-browser --headed` with the user's session, or have the user check the page.
- ASINs from search snippets are frequently hallucinated — always verify `/dp/<ASIN>` resolves to the expected product title before citing a link.

## LinkedIn / Instagram

Login-walled. `agent-browser --headed`; for LinkedIn follow the LinkedIn section in the `agent-browser` skill (login flow, `/details/experience/` URLs).

## YouTube

`summarize <url>` (direct access is blocked for agents; see repo instructions). `--extract` prints the raw transcript instead of a summary (pipe to a file under `tmp/` when a subagent needs the full text); `--length short|medium|long|xl` and `--lang ja` control the summary. Don't hand-roll yt-dlp + VTT cleanup: summarize already does that (`--youtube yt-dlp` forces that source).

| archive.org (2026-09-10) | `archive.org/wayback/available` API 429s on the first call from httpie | `web.archive.org/web/<year>id_/<url>` via httpie `--ignore-stdin --follow` returned the archived page on the first try |
## IPFS gateways (2026-09-22)

| host | httpie | httpie+UA | agent-browser headless | note |
|---|---|---|---|---|
| ipfs.io | 429 "switching to a service worker gateway only" | 403 Cloudflare "Just a moment" | "Just a moment" | deprecated as an HTTP gateway (gatewaychanges.ipfs.io); not a bot wall to climb, use another gateway |
| dweb.link, w3s.link | 429 same notice | untested | untested | same deprecation |
| cloudflare-ipfs.com | DNS gone | | | |
| gateway.pinata.cloud | 200 JSON | | | public, rate-limited; fine for one read |
| ipfs2.seadn.io | 200 JSON | | | OpenSea's gateway (the `metadata_url` OpenSea reports); best for a collection-wide pull |
| ipfs.filebase.io | 200 JSON | | | plain httpie, single file read (2026-09-24); about 40% within 6 s under 8-way concurrency |
