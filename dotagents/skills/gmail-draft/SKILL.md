---
name: gmail-draft
description: Create Gmail drafts via gog using an HTML body to avoid plain-text wrapping at ~78 chars that breaks lines mid-sentence. Use when drafting any Gmail message (reply or new) with multi-paragraph or bulleted content. Always drafts for user review; does not send.
---

# Gmail Draft

Draft a Gmail message through `gog` using HTML, avoiding the plain-text wrap-mid-sentence issue.

## Why this skill exists

`gog gmail draft create --body` and `--body-file` (both plain text) hard-wrap at ~78 chars per RFC 2822, inserting CRLFs mid-sentence. Most clients don't reflow non-`format=flowed` plain text, so the recipient sees broken lines. Draft with `--body-html-file` instead.

(Historical: a `draft.ts` wrapper in this skill predates gog's `--body-html-file` and is no longer needed. Don't use it — it silently forwards only the last `--attach`.)

## Workflow

1. Write the email body as HTML to a project-local `tmp/drafts/<name>.html` (or `/tmp/drafts/` if the project has no `tmp/`). The `drafts/` segment is what triggers the publish-bound prose hook (no emdash/§ check), and project `tmp/` is covered by the global gitignore so files won't be committed accidentally.
2. Run:

```bash
gog gmail draft create -a <gmail-account> \
  --to <email> \
  --subject "..." \
  --body-html-file <html-file> \
  [--cc "<emails>"] \
  [--bcc "<emails>"] \
  [--reply-to-message-id <id>] \
  [--quote] \
  [--attach <file>]   # repeatable for multiple attachments
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

- Wrap the whole body in an outer `<div dir="ltr">...</div>` (matches Gmail native compose, so iOS continuations inherit consistent font/size).
- **Never set `font-size` (no `style="font-size:small"`).** The user's account has no Gmail default text style, so native browser compose emits unstyled divs and mobile Gmail renders them at its full default size. An explicit `font-size:small` pins ~13px and renders visibly smaller than the user's own messages on iOS (verified side-by-side 2026-07). No inline styles at all on content divs.
- **Each top-level block must be `<div class="gmail_default">...</div>`.** This class is the marker Gmail's web editor uses to treat the content as native compose. Without it, imported drafts go into a "foreign content" mode where Ctrl-H, Delete, and Ctrl-F (forward-char) misbehave when the user reviews/edits the draft.
- Blank lines between blocks: use spacer rows of the form `<div class="gmail_default"><br></div>`. Never bare `<div><br></div>` — divs without `gmail_default` confuse the editor (Ctrl-F across one inserts an unexpected line break). Consecutive content divs with no spacer render as single-spaced lines, which reads cramped between paragraphs.
- Bullets: wrap `<ul><li>...</li></ul>` inside a `gmail_default` div, e.g. `<div class="gmail_default"><ul><li>One</li><li>Two</li></ul></div>`. Avoid `-` text prefixes — they read as plain dashes, not bullets.
- Bold: `<b>...</b>`. Avoid inline styles and `<style>` blocks.
- Quotes inside body: prefer `&quot;` for safety.

## Standard structure and signature

Default layout for any drafted message (each line below is one `gmail_default` div; blank lines are spacer divs per the rule above):

```
Dear <name>,
(blank)
<body paragraph(s), spacer div between paragraphs>
(blank)
Best,
Takeshi
```

The sign-off and name sit on consecutive lines with NO blank spacer between them — either two adjacent `gmail_default` divs or one div with a single `<br>` (matches the user's own sent mail; a blank line there reads as a gap the user never types). For personal mail from tks.ohishi@gmail.com the signature is just the name; for other accounts the signature block is one div with `<br>` line breaks inside (name / title+company / email / phone as applicable). Signatures are account-specific: check the project's AGENTS.md for a "Signature" entry matching the `-a` account before composing; if none exists, ask the user once and suggest saving it there.

## Wording

- Write like a person, not a spec. The email reads as written by the user; technical qualifiers sound machine-generated. Example the user corrected: "around 5:10 pm, Eastern Daylight Time (UTC-4)" → "around 5:10 pm Eastern Time (New York)". Before finalizing, reread for phrasing no ordinary correspondent would use (UTC offsets, RFC-style dates, over-qualified units) and simplify.

## Common gotchas

- **Account**: pass `-a <email>` when multiple Gmail accounts are configured for `gog`.
- **Threading**: `--reply-to-message-id` sets In-Reply-To/References; Gmail keeps the draft in-thread.
- **Subject**: prefix with `Re: ` for replies — `gog` does not auto-derive it.
- **Reply-all recipients**: `gog` does not auto-populate To/Cc from the thread. Construct them explicitly per "Replies: always reply-all" above.
- **Find the latest message** in a thread before reply: `gog gmail thread get <threadId> -a <account> --json | jq -r '.thread.messages[-1].id'`.
- **Flag ordering**: flags go *after* the subcommand chain (`gog gmail draft create --to ...`), not before.
