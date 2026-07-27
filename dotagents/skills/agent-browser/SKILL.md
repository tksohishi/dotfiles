---
name: agent-browser
description: Operating manual for the `agent-browser` CLI - session/profile config, the open/snapshot/get-text flow, headed mode for Cloudflare and sign-in walls, LinkedIn, and recovery from a wedged daemon. Load before driving a browser, when a daemon misbehaves (SingletonLock, respawned Chrome, stale flags), or when a page needs a real browser rather than WebFetch.
---

# agent-browser

Global instructions already fix the two rules that must hold without loading anything: use `agent-browser` for browser automation, and never drive the real installed Chrome. Everything below is how to actually operate it.

Never guess subcommands. Run `agent-browser --help` if unsure. Always close when done: `agent-browser close`.

## Workflow

- Common flow: `open <url>` → `snapshot -ic` → `get text <selector>` → `close`.
- To read page content: `snapshot` (accessibility tree with refs) or `get text @ref` (element text).

## Per-project config (authoritative)

- Each project gets `agent-browser.json` at its root (use the `/agent-browser-init` skill to generate). This is the source of truth for per-project browser behavior; do not override with `--session` / `--profile` flags.
- The config sets `session` (unique per-project daemon, enables parallel use across projects) and `profile: .agent-browser` (project-local Chrome user-data-dir, required for parallel Chrome instances to avoid `SingletonLock` conflicts).
- `agent-browser close` closes the current project's session; `close --all` closes every active session across projects.

## Headed mode (for Cloudflare, sign-in, cookie capture)

- Use `--headed` for flows that need a visible browser.
- Pass `--headed` on every call that should stay attached to a headed daemon. If the launch options don't match the daemon's current config, the daemon can respawn Chrome and lose page state.
- The warning `<flags> ignored: daemon already running` fires whenever any launch-time flag (`--headed`, `--profile`, `--args`, etc.) is re-passed against a running daemon, regardless of whether the value matches; it's cosmetic (nothing breaks). Suppress with `-q` or `--json`.
- Verify headed mode is active: `pgrep -lf "Google Chrome for Testing" | grep -v crashpad | grep -v Helper`; output must NOT contain `--headless=new`.
- Cloudflare challenges auto-clear within 2-3s in truly-headed mode; they never clear in headless.

## LinkedIn

- Requires login. If not logged in: `agent-browser close`, then `agent-browser --headed open "https://www.linkedin.com/login"`. After login, navigate to the target profile.
- For profiles, go directly to `/details/experience/` or `/details/education/` URLs to skip the Activity feed and get structured career data.

## X / Twitter

Profiles render logged out: `open https://x.com/<handle>` then `get text body`. Articles (`x.com/i/article/<id>`) do not; the browser profile is not signed in to X, so they redirect to the login flow. Use `/x-search` for those. See the `fetch-blocked` skill for the full site map.

## Recovery

When stuck, clean restart with `agent-browser close --all`. Avoid `pkill`; it leaves a stale `SingletonLock` in the profile dir that breaks subsequent launches.
