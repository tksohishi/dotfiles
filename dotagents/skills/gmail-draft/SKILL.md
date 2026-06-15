---
name: gmail-draft
description: Create Gmail drafts via gog using an HTML body to avoid plain-text wrapping at ~78 chars that breaks lines mid-sentence. Use when drafting any Gmail message (reply or new) with multi-paragraph or bulleted content. Always drafts for user review; does not send.
---

# Gmail Draft

Draft a Gmail message through `gog` using HTML, avoiding the plain-text wrap-mid-sentence issue.

## Why this skill exists

`gog gmail draft create --body` and `--body-file` (both plain text) hard-wrap at ~78 chars per RFC 2822, inserting CRLFs mid-sentence. Most clients don't reflow non-`format=flowed` plain text, so the recipient sees broken lines. `gog` has `--body-html=STRING` but no `--body-html-file`, and the inline-string form is fragile when the body contains quotes or apostrophes.

This skill ships a wrapper (`draft.ts`) that reads an HTML file and passes its contents to `gog` correctly.

## Workflow

1. Write the email body as HTML to a project-local `tmp/drafts/<name>.html` (or `/tmp/drafts/` if the project has no `tmp/`). The `drafts/` segment is what triggers the publish-bound prose hook (no emdash/§ check), and project `tmp/` is covered by the global gitignore so files won't be committed accidentally.
2. Run:

```bash
bun ~/.claude/skills/gmail-draft/draft.ts \
  --to <email> \
  --subject "..." \
  --body-file <html-file> \
  -a <gmail-account> \
  [--cc "<emails>"] \
  [--bcc "<emails>"] \
  [--reply-to-message-id <id>] \
  [--quote] \
  [--attach <file>]
```

3. Confirm the draft was created. The user reviews in Gmail before sending. Never send directly.

## Replies: always reply-all

When drafting a reply, emulate "reply-all" by default, not "reply to sender only". Build the recipients from the message you're replying to:

- `--to`: the original sender (`From`) plus everyone in the original `To`.
- `--cc`: everyone in the original `Cc`.
- Always drop the user's own address (the `-a <account>` identity) from both lists so they don't email themselves. De-duplicate addresses across To/Cc.

Pull the headers from the latest message in the thread:

```bash
gog gmail thread get <threadId> -a <account> --json \
  | jq -r '.thread.messages[-1].payload.headers[] | select(.name|test("^(From|To|Cc)$";"i")) | "\(.name): \(.value)"'
```

If the user explicitly says "reply only to the sender" (or similar), fall back to sender-only.

## HTML conventions

- Wrapper auto-wraps the body file in `<div dir="ltr">...</div>` (matches Gmail native compose, so iOS continuations inherit consistent font/size). Don't add the outer wrapper yourself.
- **Each top-level block must be `<div class="gmail_default" style="font-size:small">...</div>`.** This class is the marker Gmail's web editor uses to treat the content as native compose. Without it, imported drafts go into a "foreign content" mode where Ctrl-H, Delete, and Ctrl-F (forward-char) misbehave when the user reviews/edits the draft.
- Don't insert `<div><br></div>` spacer rows between paragraphs. Bare divs without `gmail_default` confuse the editor — Ctrl-F across one inserts an unexpected line break. Paragraph spacing comes from the class's CSS; consecutive `gmail_default` divs render with normal spacing.
- Bullets: wrap `<ul><li>...</li></ul>` inside a `gmail_default` div, e.g. `<div class="gmail_default" style="font-size:small"><ul><li>One</li><li>Two</li></ul></div>`. Avoid `-` text prefixes — they read as plain dashes, not bullets.
- Bold: `<b>...</b>`. Avoid inline styles and `<style>` blocks beyond the required `style="font-size:small"` on `gmail_default` divs.
- Quotes inside body: prefer `&quot;` for safety.

## Line breaks for readability

Use judgment to make the email scan well; these are guidelines, not a mechanical wrap.

- Favor several short `gmail_default` paragraphs over one dense block. Split when the topic shifts (greeting, context, the ask, closing) so the reader gets visual breathing room.
- Within a paragraph, add `<br>` at natural clause boundaries when a line runs long, but never hard-wrap mid-clause. Let short lines stay on one line.
- Japanese bodies: break at 文節 boundaries (roughly every 20–35 chars) the way a hand-written business mail reads, and honor kinsoku — don't start a line with 。、 or a closing bracket. Keep particles with the word they attach to.
- English bodies: lean on paragraph divs and let the client wrap; reach for `<br>` only for deliberate structure (address blocks, signatures, short stacked lines).
- Goal is a clean, well-paced email, not a fixed column width. When in doubt, fewer manual breaks.

## Common gotchas

- **Account**: pass `-a <email>` when multiple Gmail accounts are configured for `gog`.
- **Threading**: `--reply-to-message-id` sets In-Reply-To/References; Gmail keeps the draft in-thread.
- **Subject**: prefix with `Re: ` for replies — `gog` does not auto-derive it.
- **Reply-all recipients**: `gog` does not auto-populate To/Cc from the thread. Construct them explicitly per "Replies: always reply-all" above.
- **Find the latest message** in a thread before reply: `gog gmail thread get <threadId> -a <account> --json | jq -r '.thread.messages[-1].id'`.
- **Flag ordering**: flags go *after* the subcommand chain (`gog gmail draft create --to ...`), not before.
