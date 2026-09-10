---
name: telegram-context
description: Read Telegram messages, chats, and channels via the `tg` CLI to inject conversation context into the session. Use when the user asks to check Telegram, a Telegram channel/group/DM, or references a Telegram message — never scrape t.me or web.telegram.org via browser tools. Read-only; does not post.
---

## Usage

`tg --help` and per-subcommand `--help` are complete; the flow and gotchas below are what they don't say.

- Flow: `tg chats --filter <name>` to find the chat (fuzzy match — user-supplied names rarely match exactly), then `tg read <chat>` for messages, `tg context <chat> <message_id>` for surrounding discussion when a single hit needs its thread.
- `tg read` needs the exact chat name from `tg chats`; it does not fuzzy-match. DMs are named by the person's full display name, often with a suffix (`Tamara Lerner | Rootstock Collective`), so a bare name guess fails with `Cannot find chat`. Never skip the `tg chats --filter` step for a DM, even when the name feels obvious.
- Never suppress stderr on `tg read` (`2>/dev/null`, `2>&1 | jq`). A lookup failure prints `Read failed: Cannot find chat ...` and exits 1; piped into `jq` it looks identical to an empty window, and "no messages" then gets reported as fact. Run `tg read` bare first, add `jq` only once it returns JSONL.
- Output is JSONL by default; pipe to `jq` for filtering. Use `--pretty` only for excerpts shown to the user.
- `sender_id` is the stable sender key; `sender_username` may be null. For `--from`, prefer username or numeric ID — display names are ambiguous.
- `tg read` is newest-first; pass `--head` when reconstructing a conversation in reading order.

## Auth

If a read fails with an auth error, run `tg auth status` to confirm, then ask the user to run `! tg auth login` themselves — it's interactive (phone + verification code, possibly 2FA password) and can't run inside the agent.

## Caveats

- Read-only by design: there is no send/post path, so drafting a Telegram reply means giving the user text to paste, not a command.
- Public channels also go through `tg`, not the web: t.me / web.telegram.org are blocked for WebFetch by hook, and agent-browser scraping of them is off-limits by convention.
