---
name: telegram-context
description: Read Telegram messages, chats, and channels via the `tg` CLI to inject conversation context into the session. Use when the user asks to check Telegram, a Telegram channel/group/DM, or references a Telegram message — never scrape t.me or web.telegram.org via browser tools. Read-only; does not post.
---

## Usage

`tg --help` and per-subcommand `--help` are complete; the flow and gotchas below are what they don't say.

- Flow: `tg chats --filter <name>` to find the chat (fuzzy match — user-supplied names rarely match exactly), then `tg read <chat>` for messages, `tg context <chat> <message_id>` for surrounding discussion when a single hit needs its thread.
- Output is JSONL by default; pipe to `jq` for filtering. Use `--pretty` only for excerpts shown to the user.
- `sender_id` is the stable sender key; `sender_username` may be null. For `--from`, prefer username or numeric ID — display names are ambiguous.
- `tg read` is newest-first; pass `--head` when reconstructing a conversation in reading order.

## Auth

If a read fails with an auth error, run `tg auth status` to confirm, then ask the user to run `! tg auth login` themselves — it's interactive (phone + verification code, possibly 2FA password) and can't run inside the agent.

## Caveats

- Read-only by design: there is no send/post path, so drafting a Telegram reply means giving the user text to paste, not a command.
- Public channels also go through `tg`, not the web: t.me / web.telegram.org are blocked for WebFetch by hook, and agent-browser scraping of them is off-limits by convention.
