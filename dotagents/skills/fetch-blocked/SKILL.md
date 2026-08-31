---
name: fetch-blocked
description: Access content on bot-blocked sites (Reddit, X/Twitter, Cloudflare-walled pages) anonymously, without login, via URL rewrites, public endpoints, or agent-browser. Use when WebFetch is denied by the blocked-domains hook, returns 403/429 or a challenge page, or the user asks to read a Reddit thread, a tweet/post URL, or any bot-walled page.
---

# Fetch Blocked Sites

Strategy map for sites that block plain HTTP fetchers. Escalate in order: URL rewrite → public endpoint → httpie (browser UA) → agent-browser (headless, then --headed) → headed patchright real-Chrome. Don't start with a browser when a rewrite works, and don't reach for patchright before agent-browser --headed has failed.

**Every `http`/`https` (httpie) call below needs `--ignore-stdin`** (flags after the URL). Without it httpie blocks reading stdin in the Bash tool (no TTY/EOF): the command hangs, gets auto-backgrounded, then fails with exit 144 and a 0-byte body. Add `--follow` for endpoints that 302 to an empty body (e.g. Naver).

General heuristic when WebFetch fails on a domain not listed below:

- Media/content sites (news, forums, docs, shops): `http GET <url> --ignore-stdin` via httpie; if that 403s/500s, retry with a browser User-Agent header. Much of the "blocking" is specific to WebFetch's fetcher, and plain httpie from this residential IP gets through.
- Social or account-required sites (login walls, JS shells): `agent-browser --headed` with login, and only if the content is really needed; don't burn time escalating for low-value pages.

## Other verified sites (2026-06)

| Site | WebFetch | What works |
|---|---|---|
| stackoverflow.com | refused client-side | plain httpie; Stack Exchange API (`api.stackexchange.com/2.3/questions/<id>?site=stackoverflow&filter=withbody`) for structured JSON |
| nytimes.com | refused client-side | plain httpie (paywall still applies to full articles) |
| amazon.com / amazon.co.jp | 500 bot block | httpie with browser UA — see Amazon section (price gotchas) |
| naver.com | refused client-side | plain httpie + `--ignore-stdin --follow` (else 302s to an empty body); server-rendered, browser UA not needed. Only some titles expose a rating: grep ``"key":"평점"..."text":"NN/100"`` (out of 100) |
| imdb.com | empty (WAF challenge) | GraphQL endpoint for star rating; suggestion endpoint for IDs — see IMDb section |
| 5ch.net | 403 | plain httpie |
| zillow.com | 403 | plain httpie, no UA needed — see Zillow section (headless browser gets PerimeterX Press & Hold) |
| quora.com | 403 | agent-browser --headed only (403 even to httpie with browser UA) |
| glassdoor.com | Cloudflare "Humans only" terminal block | NO agent path as of Jul 30, 2026. Truly-headed agent-browser gets the terminal block, and a human completing the verification inside that Chrome is still blocked — the Chrome-for-Testing/CDP fingerprint itself is denied. Hand off: user opens the URL in their own browser and pastes content. (Worked headed as late as Jul 16, 2026; re-test occasionally.) |
| facebook.com, tiktok.com | empty JS/login shell | agent-browser --headed + login; usually not worth it |

## Sneaker / fashion retail (verified 2026-08-30)

All of these except nike.com 403 httpie even with a browser UA; the differences are in what agent-browser gets.

| Site | Headless agent-browser | What works |
|---|---|---|
| nike.com | not needed | httpie with browser UA + `--follow` (verified 2026-08-31; bare request only returns a 301). Category and product pages come back server-rendered (~1MB); on a PDP the first `<title>` is a localization string — read `og:title` or the JSON-LD `Product` node for name/price. WebFetch untested |
| footlocker.com | works (full server-rendered product + search pages) | agent-browser headless — best default for sneaker price/stock checks |
| compass.com | works (listing search + homedetails) | agent-browser headless — also the fallback for StreetEasy queries |
| cashbackmonitor.com | works | WebFetch returns 200 but rates are JS-rendered placeholders; use agent-browser headless and wait ~6s |
| snipesusa.com | Cloudflare verification page | headed patchright verified 2026-08-30 (search + product pages incl. price/size/stock render fully; ~8s wait). agent-browser --headed untested |
| adidas.com | bot page ("unable to give you access") | try --headed, then headed patchright; else hand off to user's browser |
| asics.com | Access Denied | no verified path; check the product on footlocker.com instead |
| jdsports.com | empty JS shell (~670B) | headed patchright verified 2026-08-30 (product page with price/promo/size renders; ~6s wait) |
| stockx.com | login-verify wall | headed patchright real-Chrome — see Last resort section (verified 2026-08-30); quote only the checkout total, not Ask + a memorized fee % |
| streeteasy.com | access denied | no verified path (PerimeterX class); use compass.com headless instead |
| shop.app | 429 to WebFetch | httpie with browser UA returns the full page; product title/price/vendor in embedded JSON (`rg '"name"|"price"'`). shop.app links are third-party Shopify stores — verify the seller before trusting a price |
| westnyc.com (Shopify boutiques generally) | agent-browser headless returns near-empty shell | Shopify JSON endpoints via plain httpie: `/search/suggest.json?q=...&resources[type]=product` works; `/products/<handle>.json` and `/collections/<x>/products.json` may be disabled per store |

## Last resort: headed patchright real-Chrome

When WebFetch, httpie, and both agent-browser modes fail (StockX login-verify walls, PerimeterX Press & Hold, Zillow mid-session captcha), a headed patchright launch of real Chrome Canary often still gets through — the Chrome-for-Testing/CDP fingerprint is what's being denied, not the IP. Verified: StockX (2026-08-30), Zillow while PX-blocked (2026-07).

- Needs `patchright` in the project (`bun add patchright`) and Chrome Canary installed. In `~/Work/life`, use the existing helper `lib/browser.ts` (`launchChrome`); elsewhere, the pattern is `chromium.launchPersistentContext(profileDir, { channel: 'chrome-canary', headless: false })`.
- **Always pass a persistent `profileDir`** (project-local `tmp/`) — PerimeterX-class walls trust the profile across runs; a fresh context re-triggers the wall (see patchright-bot-walls memory).
- Headed only — headless patchright fails the same as headless agent-browser. The window takes over the user's screen, so keep it to one short run and close.
- No rapid retries. If a captcha/Press & Hold renders, stop and hand the solve to the user in that window; never automate the interaction.
- Scope: reading public pages in this user-sanctioned setup (patchright is an established tool here — lib/browser.ts in life, patchright-bot-walls memory). It is NOT a license to bypass logins, rate limits, or CAPTCHAs — the CAPTCHA hard-stop from the agent-browser skill applies unchanged, and agent-browser itself stays on Chrome-for-Testing, never the user's real Chrome.

## Reddit

WebFetch refuses every reddit domain client-side ("unable to fetch"). Use httpie against `old.reddit.com`:

- HTML (works anonymously): `http GET 'https://old.reddit.com/r/<sub>/top/?t=week'` — server-rendered, pipe through `rg`/`head` to trim.
- Structured: append `.rss` (Atom XML), e.g. `https://old.reddit.com/r/<sub>/top/.rss?t=week` or `https://old.reddit.com/r/<sub>/comments/<id>/.rss` for a thread.
- Do NOT use `.json` — Reddit returns 403 to non-browser clients regardless of User-Agent.

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
| apartments.com | 403 | nothing — 403 even to httpie with browser UA (quora class); agent-browser --headed only |
| hotpads.com | untested | nothing anonymous — 200 but empty JS shell |

## LinkedIn / Instagram

Login-walled. `agent-browser --headed`; for LinkedIn follow the LinkedIn section in the `agent-browser` skill (login flow, `/details/experience/` URLs).

## YouTube

`summarize <url>` (direct access is blocked for agents; see repo instructions). `--extract` prints the raw transcript instead of a summary (pipe to a file under `tmp/` when a subagent needs the full text); `--length short|medium|long|xl` and `--lang ja` control the summary. Don't hand-roll yt-dlp + VTT cleanup: summarize already does that (`--youtube yt-dlp` forces that source).

## Cloudflare-challenged pages ("Just a moment...", 403 with cf headers)

`agent-browser --headed` — the challenge auto-clears in 2-3s headed, never headless.

## Maintenance

The WebFetch deny list with per-domain hints lives in `dotagents/hooks/webfetch-blocked-domains.txt`. When a strategy here changes or a new always-blocked domain is found, update both that file and this map.
