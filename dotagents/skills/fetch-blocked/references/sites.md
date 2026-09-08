# Site map: verified access paths per host

Look a host up with `rg -i '<host>' references/sites.md` from the skill directory; read only the matching section or row. Dates are when the path was last verified. Ladder, diagnosis rules, and the patchright-fetch runner live in SKILL.md.

## General sites

| Site | WebFetch | What works |
|---|---|---|
| safe-client.safe.global (Safe{Wallet} client gateway, e.g. `/v1/chains/1/safes/<addr>/collectibles`) | n/a (not tried) | httpie GET 403 (2026-09-04). Use the transaction service instead: `safe-transaction-mainnet.safe.global/api/v1/safes/<addr>/balances/`, `/transfers/?erc721=true` are 200 to plain httpie |
| qantas.com | 60s timeout (no block signature) | plain httpie, 200 server-rendered (~19KB, Akamai Bot Manager cookies but no challenge; verified 2026-09-02). Response is geo-routed by a `usercontext` cookie |
| help.us.puma.com (Zendesk help center) | 403 | plain httpie with browser UA, 200 (2026-09-05). Article body is in `div.article-body` |
| muji.com (JP store) | 60s timeout (no block signature) | httpie --ignore-stdin + browser UA: 30s timeout; agent-browser headless: `ERR_HTTP2_PROTOCOL_ERROR` (ASCII-only paths load with `--disable-http2`, percent-encoded Japanese paths still fail); `patchright-fetch <url> --wait 30` headed: 200, full product page (2026-09-07). muji.us is Shopify: `/products/<handle>.json` returns body_html with the size table |
| morphllm.com | 429 (WebFetch and plain httpie) | httpie with browser UA, 200 (2026-09-07). Next.js page; table content is in the RSC payload, strip tags and grep |
| hoodminer.live | n/a (not tried) | headless agent-browser gets a Cloudflare Turnstile checkbox; `http GET <url> --ignore-stdin` with a Chrome UA returns the page (2026-09-08). Pages are small (WL share badge pages under 2KB) |
| nycgovparks.org | 403 (CloudFront) | 403 to httpie+UA and headless agent-browser ("request could not be satisfied"); headed agent-browser redirects `/rules/*` to codelibrary.amlegal.com but `get text` needs a selector; `patchright-fetch <url>` headed works for both hosts, ~10s (2026-09-04) |
| voice.cc (VOICE / Social Camp, Next.js SPA) | n/a (not tried) | headless agent-browser gets Cloudflare "Just a moment"; plain httpie 200, no UA needed (2026-09-07). Page shells are Next.js: content lives in the RSC/`__NEXT_DATA__` payload, strip tags and grep. Logged-out `/socialcamp` renders only the Privy auth shell (no leaderboard) |
| sniper.xyz (Solana NFT marketplace/launchpad) | 403 | httpie plain and browser-UA also 403; headless agent-browser gets Cloudflare "Just a moment". Untested above that rung (2026-09-07) |
| nftsolana.io (Solana mint calendar, WordPress + The Events Calendar) | 403 | plain httpie, 200, no UA needed (2026-09-07). Keyless JSON at `nftsolana.io/wp-json/tribe/events/v1/events` — but it returns `total: 0`, the calendar is abandoned |
| howrare.is (Solana NFT rarity + upcoming drops) | 403 | plain httpie, 200, no UA needed (2026-09-07). Public JSON API needs no key: `api.howrare.is/v0.1/collections`, `/v0.1/drops` (drops has been returning an empty `data` array, i.e. the page is dormant, not blocked) |
| api.mainnet.tensordev.io (Tensor API) | n/a | Not a bot wall: 403 is the missing-key response. Needs `x-tensor-api-key`, granted via the Airtable access form linked from docs.tensor.trade (2026-09-07) |
| api.geckoterminal.com | n/a (not tried) | plain httpie 200. A 429 here is the free-tier rate limit (about 30 requests/min), not a bot wall: pace calls, do not escalate (2026-09-06) |
| codelibrary.amlegal.com (NYC rules mirror) | 403 | headed agent-browser loads; `patchright-fetch` headed works (2026-09-04) |
| book.qantas.com (award/cash search) | n/a (POST form from the qantas.com widget) | No verified path (2026-09-02). Headless agent-browser: `ERR_HTTP2_PROTOCOL_ERROR` on api/book hosts. Headed agent-browser fills the form logged out (no login wall) but the POST to `/qf-booking/dyn/air/tripflow.redirect` gets an Akamai "Access Denied"; patchright-fetch headed same (GET only, so not clean evidence). Untested: seeding cookies via the `/qf-booking/dyn/air/prefetcher` script then replaying the POST with httpie. Airport lookup `api.qantas.com/flight/routesearch/v1/airports?locale=en_US&queryFrom=LAX` is 200 to plain httpie. Use seats.aero (`seats` CLI, source `qantas`) for Qantas FF availability |
| walmart.com | n/a (not tried) | httpie+UA 403; agent-browser headless AND headed both land on PerimeterX "Robot or human?" Press & Hold (hard stop, do not solve); `patchright-fetch <url> --wait 35` headed returns the full product page including price block (2026-09-07). Grep the saved body for "Current price is" — the price sits ~line 600, far below sponsored-recommendation prices near the top |
| iherb.com | n/a (not tried) | httpie+UA 403; agent-browser headless gets Cloudflare "Just a moment"; agent-browser --headed clears it and renders the full product page (2026-09-07). First headed `open` after a `close` can silently keep the previous page — re-issue the `open` and check the title |
| costco.com | n/a (not tried) | httpie+UA 403; agent-browser headless `ERR_HTTP2_PROTOCOL_ERROR`; agent-browser headed Akamai "Access Denied"; `patchright-fetch <url> --wait 30` headed returns the page (2026-09-07). Prices are membership-gated: product pages show "Members Only / Sign In for Price" logged out. Query strings on category URLs (`?refine=...`) get dropped on the redirect |
| vitaminshoppe.com | n/a (not tried) | No verified path (2026-09-07). httpie+UA 403; agent-browser headless and headed both return a DataDome `var dd={...}` / geo.captcha-delivery.com stub; `patchright-fetch` headed returns an empty body (LEN 0) on both the product URL and the homepage, so the empty body is the wall, not a dead URL. Ladder exhausted |
| gnc.com | 307 to WebFetch | No verified path (2026-09-07). httpie+UA and agent-browser headless/headed all return "Access to this page has been denied"; `patchright-fetch` headed lands on a PerimeterX "Before we continue" Press & Hold (LEN 128) that did not clear in 150s with `--show`. Next attempt: rerun `--show` and solve the hold by hand; the clearance should then persist in the profile |
| shop.bodybuilding.com | n/a (not tried) | plain httpie 200, no UA needed (2026-09-07). Shopify: use `/search/suggest.json?q=<query>&resources[type]=product&resources[limit]=10` for title+price+url instead of scraping. Note: no longer carries Optimum Nutrition |
| roadtrailrun.com | Cloudflare "Just a moment" (also to headless patchright) | httpie sometimes 200, sometimes Cloudflare; `patchright-fetch` headed clears it in ~12s (verified 2026-09-02) |
| us.dailypaperclothing.com (Daily Paper) | 403 | plain httpie (no UA needed); Shopify `/products/<handle>.js` for name+price. Geo defaults to NL/EUR — append `?country=US` to the product URL for USD (verified 2026-09-02) |
| ssense.com | 403 | httpie (plain and browser UA) 403, headless agent-browser gets a Cloudflare "security verification" page; `patchright-fetch` headed returns the page (verified 2026-09-02). Delisted product URLs render a generic nav/recommendation page rather than a 404 |
|---|---|---|
| stackoverflow.com | refused client-side | plain httpie; Stack Exchange API (`api.stackexchange.com/2.3/questions/<id>?site=stackoverflow&filter=withbody`) for structured JSON |
| nytimes.com | refused client-side | plain httpie (paywall still applies to full articles) |
| amazon.com / amazon.co.jp | 500 bot block | httpie with browser UA — see Amazon section below (price gotchas) |
| naver.com | refused client-side | plain httpie + `--ignore-stdin --follow` (else 302s to an empty body); server-rendered, browser UA not needed. Only some titles expose a rating: grep ``"key":"평점"..."text":"NN/100"`` (out of 100) |
| imdb.com | empty (WAF challenge) | GraphQL endpoint for star rating; suggestion endpoint for IDs — see IMDb section below |
| 5ch.net | 403 | plain httpie |
| ccn.com | 403 | plain httpie, no UA needed (verified 2026-09-04) |
| blofin.com | 403 | No path below patchright: httpie plain and browser-UA both 403 (2026-09-04); agent-browser/patchright rungs not tried (content was redundant) |
| zillow.com | 403 | plain httpie, no UA needed — see Zillow section below (headless browser gets PerimeterX Press & Hold) |
| quora.com | 403 | agent-browser --headed only (403 even to httpie with browser UA) |
| glassdoor.com | Cloudflare "Humans only" terminal block (agent-browser, even truly-headed with a human solving — the Chrome-for-Testing/CDP fingerprint itself is denied) | headed patchright verified 2026-08-31 (company reviews page renders anonymously incl. pros/cons; ~8s wait) |
| facebook.com, tiktok.com | empty JS/login shell | agent-browser --headed + login; usually not worth it |
| nado.xyz (Nado orderbook DEX on Ink, Framer-hosted) | 403 | plain httpie `--ignore-stdin` (no custom UA), 200 (2026-09-08). Framer site: article prose is in the page HTML, strip tags and grep; `/articles` index is empty (client-rendered), so hit `/articles/<slug>` directly |
| jobs.lever.co (Lever job boards, e.g. `/Flex/`) | 403 | plain httpie `--ignore-stdin` (no custom UA), 200 server-rendered board (2026-09-08). Better: public API `https://api.lever.co/v0/postings/<slug>?mode=json` (list) and `/v0/postings/<slug>/<id>` (one posting, `descriptionPlain` + `lists`), 200 to httpie |
| theinfatuation.com | works — returns the real rendered review text | WebFetch is the correct tool here (2026-09-08). httpie plain and with a browser UA returns only a ~2.5KB JS shell (same shell on the `/new-york` hub, so it is the shell, not a dead page); agent-browser headless renders the page fully. Gotcha: on a spot they have not visited the page really does say "We haven't been here yet, but want you to know this spot exists" — that is the actual content, not a truncated fetch, so do not escalate the ladder over it |
| yelp.com | 403 (DataDome) | `patchright-fetch <url> --show` + user solves the DataDome slider once (2026-09-08); the clearance persists in the shared profile and later offscreen `--wait 40` runs should pass. On a fresh profile the offscreen run does not pass by itself, so notify the user and run `--show` first. httpie+UA 403 on both a biz page and the homepage; agent-browser headless AND headed both return the DataDome `var dd={...}` / `geo.captcha-delivery.com` stub (~410 bytes, confirmed on the homepage too). On a biz page the aggregate "Popular Dishes" block (dish name + review count) sits near the top and is the cheapest way to get dish counts across all reviews; the body text carries only page 1 of reviews (~9 of N), so paginating costs another headed run per page |

## Sneaker / fashion retail (verified 2026-08-30)

All of these except nike.com 403 httpie even with a browser UA; the differences are in what agent-browser gets.

| Site | Headless agent-browser | What works |
|---|---|---|
| nike.com | not needed | httpie with browser UA + `--follow` (verified 2026-08-31; bare request only returns a 301). Category and product pages come back server-rendered (~1MB); on a PDP the first `<title>` is a localization string — read `og:title` or the JSON-LD `Product` node for name/price. WebFetch untested |
| footlocker.com | works (full server-rendered product + search pages) | agent-browser headless — best default for sneaker price/stock checks |
| compass.com | works (listing search + homedetails) | agent-browser headless — also the fallback for StreetEasy queries |
| cashbackmonitor.com | works | WebFetch returns 200 but rates are JS-rendered placeholders; use agent-browser headless and wait ~6s |
| snipesusa.com | Cloudflare verification page | headed patchright verified 2026-08-30 (search + product pages incl. price/size/stock render fully; ~8s wait). agent-browser --headed untested |
| adidas.com | bot page ("unable to give you access") | headed patchright verified 2026-08-31 (product page incl. price/description/reviews renders; ~8s wait). agent-browser --headed untested |
| asics.com | Access Denied | headed patchright verified 2026-08-31 (Training category page renders fully, ~8s wait); quick checks: footlocker.com headless |
| jdsports.com | empty JS shell (~670B) | headed patchright verified 2026-08-30 (product page with price/promo/size renders; ~6s wait) |
| stockx.com | login-verify wall | headed patchright real-Chrome — see Last resort in SKILL.md (verified 2026-08-30); quote only the checkout total, not Ask + a memorized fee % |
| streeteasy.com | access denied | `patchright-fetch --show` + user solves Press & Hold once, verified 2026-08-31; PX trust persists in the shared profile, later offscreen runs pass in ~6s. Fresh profile always re-triggers the wall. compass.com headless as the no-user fallback |
| dickssportinggoods.com | 403 (WebFetch and httpie+UA) | headed patchright verified 2026-08-31 (search results with prices render; ~20s wait) |
| pacsun.com | 403 (WebFetch, httpie+UA, headless agent-browser "Access to this page has been denied") | headed patchright verified 2026-09-02 (homepage promo banners render; ~25s wait) |
| runningwarehouse.com | 406 Not Acceptable | httpie with browser UA (verified 2026-08-31; plain httpie untested). Headed patchright also works. A 404 on a Google-indexed descpage URL means the product was delisted, not a block |
| shop.app | 429 to WebFetch | httpie with browser UA returns the full page; product title/price/vendor in embedded JSON (`rg '"name"|"price"'`). shop.app links are third-party Shopify stores — verify the seller before trusting a price |
| westnyc.com (Shopify boutiques generally) | agent-browser headless returns near-empty shell | Shopify JSON endpoints via plain httpie: `/search/suggest.json?q=...&resources[type]=product` works; `/products/<handle>.json` and `/collections/<x>/products.json` may be disabled per store |

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
| apartments.com | 403 | headed patchright verified 2026-08-31 (search results with listing prices render; ~8s wait); agent-browser --headed also an option |
| hotpads.com | untested | httpie/WebFetch get an empty JS shell; headed patchright verified 2026-08-31 (listings with prices render; ~8s wait) |

## LinkedIn / Instagram

Login-walled. `agent-browser --headed`; for LinkedIn follow the LinkedIn section in the `agent-browser` skill (login flow, `/details/experience/` URLs).

## YouTube

`summarize <url>` (direct access is blocked for agents; see repo instructions). `--extract` prints the raw transcript instead of a summary (pipe to a file under `tmp/` when a subagent needs the full text); `--length short|medium|long|xl` and `--lang ja` control the summary. Don't hand-roll yt-dlp + VTT cleanup: summarize already does that (`--youtube yt-dlp` forces that source).

## Airline award search (verified 2026-09-03)

| Site | WebFetch / httpie | agent-browser headless | agent-browser --headed | patchright-fetch headed |
|---|---|---|---|---|
| aa.com | untested | Akamai "Access Denied" + `Reference #18.…` | same Access Denied (headed does NOT clear it) | works |
| jal.co.jp | 403 to WebFetch and httpie+browser UA (2026-09-05) | untested | untested | works (`/jp/en/inter/service/economy/seat/A350-1000.html`; `/jp/en/aircraft/conf/A350-1000.html` is a dead URL, the aircraft page is `/conf/351.html`) |
| starlinkflights.com | WebFetch 403; httpie+browser UA returns a 2.5KB JS shell, no content (2026-09-05) | untested | untested | untested (low value; travelsort.com Starlink roundup fetches fine via WebFetch) |
| t-mobile.com | WebFetch 403; httpie+browser UA returns a 2KB JS shell (2026-09-05) | untested | untested | works on a live URL (`/benefits/travel/in-flight-wifi`); a dead URL renders nav only with an empty title, so check the title before calling the host blocked |
| delta.com | untested | Akamai "Access Denied" + `Reference 0.…` | booking form renders and can be driven | page renders |
| aircanada.com | untested | booking form renders and can be driven; the award **results** URL is Akamai "Access Denied" + `Reference #18.…` | not needed (headless drives the form) | booking page renders; award results URL redirects to `/clogin/pages/login` |
| united.com | untested | `ERR_HTTP2_PROTOCOL_ERROR` on every path incl. the homepage | deeplink renders and can be driven | deeplink renders, but results stay on "Loading results…" |

**aa.com** — the whole award search is URL-encodable, so no form driving is needed. One `patchright-fetch` on a deeplink returns the full results page as text:

```bash
patchright-fetch 'https://www.aa.com/booking/search?locale=en_US&pax=1&adult=1&type=OneWay&searchType=Award&slices=%5B%7B%22orig%22%3A%22JFK%22%2C%22origNearby%22%3Afalse%2C%22dest%22%3A%22HND%22%2C%22destNearby%22%3Afalse%2C%22date%22%3A%222026-12-01%22%7D%5D' --wait 45
```

It redirects to `/booking/choose-flights/1?sid=<uuid>`; that sid URL is session-bound, but the deeplink itself reproduces the search from cold. Rows read as text anchors: `One way Business <N>K + $<tax> for <ORIG> to <DEST>, departing at <time>`, plus `Not available` where the cabin has no award space.

**delta.com** — headed agent-browser drives the Book a Flight form fine (Shop with Miles checkbox, airport pickers, calendar), but submitting fails: the award search returns in-page error `#SFAF052_444`, and the cash search navigates to `/flightsearch/search-results` which is a hard Akamai Access Denied. The results URL carries only `?cacheKeySuffix=<uuid>` and is session-bound — reopening it in patchright bounces back to `book-a-flight` with `#SFAF100826`. No verified path to Delta award results logged out.

**delta.com deep link (verified 2026-09-03)** — the Book a Flight widget is an Angular app (`/flightsearch/8.0.31/main-*.js` + `chunk-*.js`). `chunk-XK7UNFV4.js` maps the page's query string onto the widget state, whitelisting exactly these names: `paxCount`, `originCity`, `destinationCity`, `tripType`, `flexAirport`, `datesFlexible`, `cabinFareClass`, `departureDate`, `awardTravel`, `returnDate`, `meetingEventCode`, `refundableFlightsOnly`. `originCity`/`destinationCity` are validated as 3-letter airport codes despite the name. `tripType` takes `ONE_WAY` / `ROUND_TRIP` / `MULTICITY`. Dates are split on `-` or `/` and read year-first when the first part is > 31, so `YYYY-MM-DD` works. `awardTravel` is compared against the string `"true"` and drives the Shop with Miles checkbox.

```
https://www.delta.com/flightsearch/book-a-flight?originCity=JFK&destinationCity=HND&departureDate=2026-12-01&tripType=ONE_WAY&paxCount=1&awardTravel=true
```

Confirmed in headed agent-browser: the widget renders `JFK | HND | One Way | Dec 1 | 1` with the `shopWithMiles` checkbox checked. Verdict: yes for prefill, no for results — the human still presses Find Flights, and the results hop is still the session-bound `search-results?cacheKeySuffix=<uuid>` Akamai wall above.

**aircanada.com (Aeroplan)** — no bot wall on the booking page, but Aeroplan award results are **login-walled**. Headless agent-browser drives the US-edition form fine (checkbox "Book with Aeroplan points", One-way, JFK/HND, date typed as `DD/MM`); the form then shows "Please sign in to book with Aeroplan points." and Search is inert. Accepting the "you will be redirected to the Canadian edition" dialog (OK) navigates to a clean, fully URL-encoded deeplink:

```
https://www.aircanada.com/aeroplan/redeem/availability/outbound?org0=JFK&dest0=HND&departureDate0=2026-12-01&ADT=1&YTH=0&CHD=0&INF=0&INS=0&lang=en-CA&tripType=O&marketCode=INT
```

That URL is not session-bound, but neither rung reads it logged out: headless agent-browser gets the Akamai Access Denied, and `patchright-fetch '<url>' --wait 60` redirects to `https://www.aircanada.com/clogin/pages/login?gig_client_id=…` (Aeroplan sign-in). Guessed booking deeplinks on `/booking/flights?org0=…` are silently ignored — the params drop and the page lands on `/home/<ed>/en/aco/flights`. No verified path to Aeroplan award prices logged out.

**united.com (MileagePlus)** — award results are **login-walled**, stated in-page: "We can show you flight results with money. You must be signed-in to see flight results with miles." The `/en/us/fsr/choose-flights` deeplink is honoured (origin, destination, date, pax, and `at=1` pre-selecting the "Show price in: Miles" dropdown):

```
https://www.united.com/en/us/fsr/choose-flights?f=JFK&t=HND&d=2026-12-01&tt=1&at=1&sc=3&px=1&taxng=1&newHP=True&clm=7&st=bestmatches&tqp=A
```

but the results pane never leaves "Loading results…" for patchright-fetch (`--wait 120`) or for headed agent-browser until you dismiss the cookie banner and the sign-in modal and press **Update**, which is when the sign-in requirement surfaces. Choosing "Show flights with money" flips the URL to `at=0` and returns "We're sorry, but united.com was unable to complete your request." — a generic error, not an Akamai block. Headless agent-browser can't reach united.com at all (`ERR_HTTP2_PROTOCOL_ERROR`, same signature as book.qantas.com). Use seats.aero for UA/AC award space.

**qantas.com award search deep link (verified 2026-09-03)** — the search widget on qantas.com pages is a React app (`https://static.qantas.com/ams02/a974/38/prod/master/consider_widgets/current/app.js`, mapped from `https://www.qantas.com/scripts/sites/qcom/config/prod.js` under `widgets["flight-search"].scriptPath`). It renders `<form method="post">` with `action` = `https://book.qantas.com/pl/QFAward/wds/tripflow.redirect` for awards and `https://book.qantas.com/{languagePrefix}qf-booking/dyn/air/tripflow.redirect` for cash; posted field names include `depAirports`, `destAirports`, `travelDates`, `travelClass`, `numberOfAdults`, `numberOfYoungAdults`, `numberOfChildren`, `numberOfInfants`, `searchOption`, `isClassicSearch`, `isClassicOnly`, `client`, plus hidden `APPLICATION_NAME`, `ENTRY_POINT`, `PAGE_FROM`, `USER_LANG`, `USER_LOCALE`, `WDS_SERVICE_ID`, `FF_MEMBER_ID`, `FF_TOKEN`. So the results step is POST-only — no GET deep link to book.qantas.com.

The widget itself *does* read a query string off its host page (`K.parse(window.location.search)` → `mapToReduxState`) and prefills when any of these are present: `departureAirportCode`, `arrivalAirportCode`, `departureDate`, `returnDate` (both `YYYY-M-D`, regex `^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$`), `tripType` (`O` one way / `R` return), `travelClass` (`ECO`/`PRM`/`BUS`/`FIR`/`ALL`), `usePoints`, `adults`, `youths`, `children`, `infants`. Candidate widget-prefill link (built only from observed names, **not** confirmed rendering):

```
https://www.qantas.com/us/en.html?departureAirportCode=JFK&arrivalAirportCode=HND&departureDate=2026-12-01&tripType=O&travelClass=BUS&adults=1&usePoints=true
```

Verdict: partial — prefill-the-widget yes, jump-to-results no; the human still has to press Search. Unverified in-browser because after one successful headed load `www.qantas.com` started returning `net::ERR_HTTP2_PROTOCOL_ERROR` to every subsequent navigation (same signature as united.com), while plain httpie still gets 200 on the same URL. Don't retry the browser rung on qantas.com in the same session.

Qantas prefill link confirmed by hand (2026-09-03): `https://www.qantas.com/us/en/book-a-trip/flights.html?departureAirportCode=JFK&arrivalAirportCode=HND&departureDate=2026-12-1&tripType=O&travelClass=BUS&adults=1&usePoints=true` fills the widget; the `/us/en.html` host page and a zero-padded date do not.
