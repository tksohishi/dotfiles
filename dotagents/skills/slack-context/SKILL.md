---
name: slack-context
description: Read recent Slack messages from the current repo's workspace via `slk` to inject team discussion context into the session. Use when the user references a Slack thread, channel discussion, or asks what the team said about a topic — only when the repo's `.env.local` has SLACK_XOXC_TOKEN and SLACK_COOKIE_D. Read-only; does not post.
---

## Usage

- `slk channels` — list joined channels sorted by latest activity (most recent first); `*` marks unreads. Add `--since 4h` to filter to recently-active only, or `--all` to see the full workspace list.
- `slk messages <#name|Cxxxx> [--limit N] [--since 4h|YYYY-MM-DD]` — recent top-level messages. Default limit 50.
- When a parent message shows `(N replies, ts=…)`, follow up with `slk thread <channel> <ts>` to read the full discussion. Slack archive URLs also work: `slk thread https://workspace.slack.com/archives/Cxxxx/p1714817640123456`.
- `slk download <file-url> [--out <path>]` — save a Slack-hosted file (PDF, image, video, etc.) when the user shares a file copy-link or pastes a Slack file URL. Accepts both `https://<workspace>.slack.com/files/.../F.../name` and `https://files.slack.com/files-pri/...` forms. Defaults to CWD with the original filename; if `--out` is a directory, the file lands inside it.
- Attachments (screenshots, videos) are NOT a dead end: a message with a file shows an empty/short text line in plain output, but `--json` carries the file objects. Get the link with `slk messages <chan> --since <date> --json | jq -r '.[] | select(.files) | .files[0].permalink'`, `slk download` it, then ANALYZE it — Read the image directly (screenshots often contain the exact error text or UI state under discussion); for videos, extract frames with `ffmpeg -ss <t> -i <file> -frames:v 1 out.png` and Read those. Never tell the user a shared screenshot can't be seen without trying this path first.
- Output is plain text and can be quoted directly back to the user. Add `--json` for programmatic use.
- `slk` prints all timestamps in UTC (`YYYY-MM-DD HH:MM`). When quoting times back to the user, convert to local time and label the zone (e.g. ET) — run `date` once to get the machine's current offset, then adjust. Keep the UTC value alongside only if dropping it would be ambiguous.

## Auth setup (manual, per workspace)

The repo's `.env.local` must contain two values, extracted from a logged-in browser session (`slk` is a personal CLI and these creds are per-user, so `.env.local` is the right home — this is not a general rule that secrets go in `.env.local`):

- `SLACK_XOXC_TOKEN` — DevTools → Network on `app.slack.com` → click any channel → click any `slack.com/api/*` request → **Payload** tab → Form Data → `token=xoxc-…`.
- `SLACK_COOKIE_D` — DevTools → Application → Cookies → `https://app.slack.com` → row where Name = `d` → copy Value.

`.env.local` is covered by the user's global gitignore (`*.local`). Run `slk doctor` to validate; if it returns `invalid_auth`, the cookie or token has rotated (every few weeks) — ask the user to re-extract both.

## Caveats

- xoxc + cookie auth is unofficial. Personal read-only use only; do not script high-volume polling.
- First 1000 channels are matched by `#name`; for workspaces beyond that, pass the channel ID.
- If `slk channels` or `slk messages` returns `not_authed` or `invalid_auth` on first run, the auth shape may differ for this workspace — surface the exact error to the user rather than retrying.
