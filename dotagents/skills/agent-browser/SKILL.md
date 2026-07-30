---
name: agent-browser
description: Operating manual for the `agent-browser` CLI - session/profile config, the open/snapshot/get-text flow, headed mode for Cloudflare and sign-in walls, LinkedIn, and recovery from a wedged daemon. Load before driving a browser, when a daemon misbehaves (SingletonLock, respawned Chrome, stale flags), or when a page needs a real browser rather than WebFetch.
---

# agent-browser

Global instructions already fix the two rules that must hold without loading anything: use `agent-browser` for browser automation, and never drive the real installed Chrome. Everything below is how to actually operate it.

Never guess subcommands. Run `agent-browser --help` if unsure. Always close when done: `agent-browser close`.

## Workflow

- **Delegate to a subagent.** Multi-step agent-browser work (investigation, form filling, scraping) runs in a subagent, not the main loop — it's high tool-call volume and, in headed mode, steals the user's screen focus. The main context sends the goal + known page quirks and gets a bounded summary back. A quick single lookup (open → get text → close) may stay inline. This is also a token rule: every snapshot dumped into the main context is re-sent on all later turns for the rest of the session.
- **ONE driver at a time per project.** All agents in a project share one daemon and one tab; two agents driving it concurrently fight — each contested `open` re-navigates the other's page, and on a headed daemon every round re-raises the window (Jul 30, 2026: parallel research subagents caused a focus-stealing loop). Never run agent-browser from parallel subagents; put all browser work for a task in a single agent and serialize it. When delegating a task that might browse, say so in the prompt: at most one browser-using agent, and forbid it from spawning further agents. The `~/.dotfiles/bin/agent-browser` wrapper queues concurrent CLI calls per project as a backstop, but it can't un-interleave two agents' logical sequences — behavioral serialization is the real rule.
- Common flow: `open <url>` → `snapshot -ic` → `get text <selector>` → `close`.
- To read page content: `snapshot` (accessibility tree with refs) or `get text @ref` (element text). Prefer a scoped `get text <selector>` over repeated full snapshots when you only need one region.
- **Refs go stale.** `@ref` handles are only valid for the snapshot that produced them; any navigation, click, or DOM change invalidates them. On `Unknown ref`, don't retry the same ref or guess a neighboring one (`e69` → `e68` → `e45` is a real failure loop from a past session) — re-run `snapshot` and act on the fresh refs.
- **Screenshots**: don't Read screenshot images in the main session — an image block invalidates the prompt cache and re-writes the whole context at cache-write rates. Have a subagent read the screenshot and return text findings.

## CAPTCHA and bot checks: stop, don't bypass

A CAPTCHA, "Are you a bot?", or a bot-score rejection is a hard stop. Never spoof the browser's automation flags, install a stealth plugin, or use a solving service. A PreToolUse hook (`no-bot-detection-bypass.sh`) denies these outright, so attempts fail loudly rather than quietly succeeding.

Hand the task to the user instead: save the values they need into a file, say which step is blocked, and let them finish in their own browser.

Also, `fill` writes instantly into every field, which is itself a bot signal. On a form whose submission is bot-scored, expect to hand off rather than to out-run the check.

## Per-project config (authoritative)

- Each project gets `agent-browser.json` at its root (use the `/agent-browser-init` skill to generate). This is the source of truth for per-project browser behavior; do not override with `--session` / `--profile` flags.
- The config sets `session` (unique per-project daemon, enables parallel use across projects) and `profile: .agent-browser` (project-local Chrome user-data-dir, required for parallel Chrome instances to avoid `SingletonLock` conflicts).
- `agent-browser close` closes the current project's session. `close --all` (every session across projects) is hook-blocked for agents (`bash-antipatterns.sh` denies any `agent-browser` call containing `--all`); if cross-project cleanup seems needed, ask the user to run it.

## Headed mode (for Cloudflare, sign-in, cookie capture)

- Headed is a last resort (Cloudflare, sign-in, cookie capture only) — the window takes over the user's screen. Try headless first, and `close` the session as soon as the headed portion is done.
- Pass `--headed` on EVERY call until the headed flow ends — including `click`, `fill`, `eval`, `snapshot`, not just `open`. A mid-sequence call without it makes the window hide and reappear (focus-stealing flicker), and a launch-option mismatch can make the daemon respawn Chrome and lose page state.
- The warning `<flags> ignored: daemon already running` fires whenever any launch-time flag (`--headed`, `--profile`, `--args`, etc.) is re-passed against a running daemon, regardless of whether the value matches; it's cosmetic (nothing breaks). Suppress with `-q` or `--json`.
- Verify headed mode is active: `pgrep -lf "Google Chrome for Testing" | grep -v crashpad | grep -v Helper`; output must NOT contain `--headless=new`.
- Cloudflare challenges auto-clear within 2-3s in truly-headed mode; they never clear in headless.

## LinkedIn

- Requires login. If not logged in: `agent-browser close`, then `agent-browser --headed open "https://www.linkedin.com/login"`. After login, navigate to the target profile.
- For profiles, go directly to `/details/experience/` or `/details/education/` URLs to skip the Activity feed and get structured career data.

## X / Twitter

Profiles render logged out: `open https://x.com/<handle>` then `get text body`. Articles (`x.com/i/article/<id>`) do not; the browser profile is not signed in to X, so they redirect to the login flow. Use `/x-search` for those. See the `fetch-blocked` skill for the full site map.

## Recovery

When stuck, clean restart with `agent-browser close` (current project's session). `close --all` is hook-blocked for agents — if the wedge spans other projects' sessions, surface it and let the user run `agent-browser close --all` themselves. Avoid `pkill`; it leaves a stale `SingletonLock` in the profile dir that breaks subsequent launches.
