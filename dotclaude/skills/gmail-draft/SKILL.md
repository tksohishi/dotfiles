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

1. Write the email body as HTML to a project-local `tmp/<name>.html` (or `/tmp/` if the project has no `tmp/`). Project `tmp/` is covered by the global gitignore, so files won't be committed accidentally.
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

## HTML conventions

- Wrap body in a single outer `<div>...</div>`.
- Paragraph break: `<div><br></div>`. Never `<p>`.
- Bullets: `-` prefix in text. Avoid `<ul>`/`<li>` unless intentional.
- Bold: `<b>...</b>`. Avoid inline styles and `<style>` blocks.
- Quotes inside body: prefer `&quot;` for safety.

## Common gotchas

- **Account**: pass `-a <email>` when multiple Gmail accounts are configured for `gog`.
- **Threading**: `--reply-to-message-id` sets In-Reply-To/References; Gmail keeps the draft in-thread.
- **Subject**: prefix with `Re: ` for replies — `gog` does not auto-derive it.
- **CC preservation**: when replying, look up the existing thread's CC list and re-pass it explicitly. `gog` does not auto-preserve.
- **Find the latest message** in a thread before reply: `gog gmail thread get <threadId> -a <account> --json | jq -r '.thread.messages[-1].id'`.
- **Flag ordering**: flags go *after* the subcommand chain (`gog gmail draft create --to ...`), not before.
