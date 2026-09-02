---
name: fetch-blocked
description: Access content on bot-blocked sites (Reddit, X/Twitter, Cloudflare-walled pages) anonymously, without login, via URL rewrites, public endpoints, agent-browser, or headed patchright; per-host verified paths in references/sites.md. Use when WebFetch is denied by the blocked-domains hook, returns 403/429 or a challenge page, or the user asks to read a Reddit thread, a tweet/post URL, or any bot-walled page.
---

# Fetch Blocked Sites

Strategy map for sites that block plain HTTP fetchers. Per-host verified paths live in `references/sites.md`; the ladder and rules are here.

**Step 0: look the host up first.** `rg -i '<host>' references/sites.md` (from this skill's directory). If there is a row or section, use that path and skip the ladder. Only unlisted hosts walk the ladder below.

Escalate in order: URL rewrite → public endpoint → httpie (browser UA) → agent-browser (headless, then --headed) → `patchright-fetch` headed (real Chrome). Don't start with a browser when a rewrite works, and don't reach for patchright before agent-browser --headed has failed. Mirrors and search engines are not a rung. A host is "unreachable" only after the last rung failed on a known-good URL; report the rungs tried per host so the caller can verify the ladder was walked. **Recording the outcome in `references/sites.md` is the last rung of the ladder, not maintenance**: the moment a rung passes (or patchright fails on a known-good URL), add the host's row with the per-method results and today's date, and add it to `dotagents/hooks/webfetch-blocked-domains.txt` when WebFetch was among the failures. "Same procedure next time" in a report means the row was skipped. The detect hook tracks blocked hosts per session and prompts for the row when an unrecorded host passes. The `fetch-blocked-detect` PostToolUse hook re-injects this rule whenever a fetch result carries a block signature, in subagents too.

**Every `http`/`https` (httpie) call below needs `--ignore-stdin`** (flags after the URL). Without it httpie blocks reading stdin in the Bash tool (no TTY/EOF): the command hangs, gets auto-backgrounded, then fails with exit 144 and a 0-byte body. Add `--follow` for endpoints that 302 to an empty body (e.g. Naver).

General heuristic when WebFetch fails on a host not in `references/sites.md`:

- Media/content sites (news, forums, docs, shops): `http GET <url> --ignore-stdin` via httpie; if that 403s/500s, retry with a browser User-Agent header. Much of the "blocking" is specific to WebFetch's fetcher, and plain httpie from this residential IP gets through.
- Social or account-required sites (login walls, JS shells): `agent-browser --headed` with login, and only if the content is really needed; don't burn time escalating for low-value pages.

**Before classifying a site as bot-walled, diagnose:**

1. Confirm the block on a known-good URL (homepage or a page you know exists) with the SAME method. A 404/410 on a deep URL is a dead page (delisted product, changed slug — re-find it via the site's own search), never a block signal. Real block signals: 403/406/429, a challenge page ("Just a moment", Press & Hold), an "Access Denied" title, or an empty JS shell on a page that should have content.
2. A block is per-method, not per-site: agent-browser getting 406/denied says nothing about httpie+UA (runningwarehouse: headless 406, httpie+UA fine). Walk the ladder in order and re-test each rung against the known-good URL; don't skip to patchright because a lower rung failed on a URL that was simply dead.
3. Only after the ladder is exhausted on a known-good URL is the site "no verified path" — then record it in `references/sites.md` with per-method results.

## Last resort: headed patchright real-Chrome

When WebFetch, httpie, and both agent-browser modes fail (StockX login-verify walls, PerimeterX Press & Hold, Zillow mid-session captcha), a headed patchright launch of real Chrome Canary often still gets through — the Chrome-for-Testing/CDP fingerprint is what's being denied, not the IP. Verified: StockX (2026-08-30), Zillow while PX-blocked (2026-07), asics/adidas/glassdoor/apartments.com/hotpads (2026-08-31), StreetEasy (2026-08-31, after a one-time manual Press & Hold via `--show`). PerimeterX Press & Hold on a fresh profile needs that one manual solve; the clearance then lives in the profile and offscreen runs pass until PX trust expires (days) or the IP/Chrome version changes.

- Ready-made runner on PATH: `patchright-fetch <url> [--wait <seconds>] [--show]` (dotfiles bin; bun auto-installs pinned patchright on first run, needs Chrome Canary). Per-host persistent profile under `~/.cache/patchright-fetch/`, shared across projects so a wall solved once is trusted everywhere; body text saved to `~/.cache/patchright-fetch/<host>.txt`. `--wait` is a cap (default 20s), it returns as soon as the body settles with no challenge on screen. Prefer it over writing a new script.
- The window opens offscreen by default (`--window-position=-2400,-2400` — passes the walls fine, no screen takeover; the brief app-activation focus switch at launch is unavoidable). `--show` puts it onscreen for a manual captcha/Press & Hold solve.
- Hand-rolling instead: `chromium.launchPersistentContext(profileDir, { channel: 'chrome-canary', headless: false })`.
- **Always use a persistent profile** (patchright-fetch does this automatically) — PerimeterX-class walls trust the profile across runs; a fresh context re-triggers the wall (see patchright-bot-walls memory).
- Headed only — headless patchright fails the same as headless agent-browser, even reusing a profile that headed runs already got trusted (adidas, 2026-08-31; the failed headless attempt didn't poison the profile). The window takes over the user's screen, so keep it to one short run and close.
- No rapid retries. If a captcha/Press & Hold renders, stop and hand the solve to the user in that window; never automate the interaction.
- Scope: reading public pages in this user-sanctioned setup (patchright is an established tool here — lib/browser.ts in life, patchright-bot-walls memory). It is NOT a license to bypass logins, rate limits, or CAPTCHAs — the CAPTCHA hard-stop from the agent-browser skill applies unchanged, and agent-browser itself stays on Chrome-for-Testing, never the user's real Chrome.

## Cloudflare-challenged pages ("Just a moment...", 403 with cf headers)

`agent-browser --headed` — the challenge auto-clears in 2-3s headed, never headless. If it doesn't clear, `patchright-fetch` headed (roadtrailrun.com 2026-09-02, ~12s; agent-browser --headed untested there).

## Maintenance

The WebFetch deny list with per-domain hints lives in `dotagents/hooks/webfetch-blocked-domains.txt`; block signatures that trigger the escalation reminder live in `dotagents/hooks/fetch-blocked-detect.sh`. When a strategy changes or a new always-blocked domain is found, update the deny list and `references/sites.md` (a table row for a one-liner, a section when the path needs commands or gotchas).
