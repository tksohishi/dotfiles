---
name: slack-context
description: Read recent Slack messages from the current repo's workspace via `slk` to inject team discussion context into the session. Use when the user references a Slack thread, channel discussion, or asks what the team said about a topic — only when the repo's `.env` has SLACK_XOXC_TOKEN and SLACK_COOKIE_D. Read-only; does not post.
---

## Usage

- `slk channels` — list joined channels sorted by latest activity (most recent first); `*` marks unreads. Add `--since 4h` to filter to recently-active only, or `--all` to see the full workspace list.
- `slk messages <#name|Cxxxx> [--limit N] [--since 4h|YYYY-MM-DD]` — recent top-level messages. Default limit 50.
- When a parent message shows `(N replies, ts=…)`, follow up with `slk thread <channel> <ts>` to read the full discussion. Slack archive URLs also work: `slk thread https://workspace.slack.com/archives/Cxxxx/p1714817640123456`.
- Output is plain text and can be quoted directly back to the user. Add `--json` for programmatic use.

## Auth setup (manual, per workspace)

The repo's `.env` must contain two values, extracted from a logged-in browser session:

- `SLACK_XOXC_TOKEN` — DevTools → Network on `app.slack.com` → click any channel → find a `slack.com/api/*` request → form-data field `token=xoxc-…`.
- `SLACK_COOKIE_D` — DevTools → Application → Cookies → `https://app.slack.com` → row where Name = `d` → copy Value.

Both files are covered by the user's global gitignore. Run `slk doctor` to validate; if it returns `invalid_auth`, the cookie or token has rotated (every few weeks) — ask the user to re-extract both.

## Caveats

- xoxc + cookie auth is unofficial. Personal read-only use only; do not script high-volume polling.
- First 1000 channels are matched by `#name`; for workspaces beyond that, pass the channel ID.
- If `slk channels` or `slk messages` returns `not_authed` or `invalid_auth` on first run, the auth shape may differ for this workspace — surface the exact error to the user rather than retrying.
