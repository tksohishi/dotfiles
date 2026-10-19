---
name: prose
description: Rules for writing and editing prose meant for human readers, in English or Japanese, so it reads as plain human writing without AI tells and without changing what it says. Use before drafting or revising any docs, reports, README sections, PR descriptions, emails, announcements or Google Docs, and when asked to review text for AI tells, humanize it, 推敲して, AIっぽさを消して or 自然な日本語に直して. Not for code, code comments, commit messages, or conversational chat replies.
---

# prose

Two jobs share one set of rules: drafting new text, and editing text someone else wrote (or an earlier draft of yours). The language files hold the patterns; this file holds the principles that override them.

### Pick the language file

- English: read `references/en.md`.
- Japanese: read `references/ja.md`.
- Mixed text: read both, and apply each to its own language.

Read only what applies. The patterns are signs to check, not a ban list: a pattern only justifies an edit when it actually hurts the sentence in front of you.

### Preserve meaning on four axes

Before rewriting a sentence, note these four things; after rewriting, check that they are unchanged. Every other rule applies only inside these limits.

1. Claim: what it says, and the logical relations (cause, contrast, condition, sequence). Don't swap one concept for a neighbor ("the core of X" is not "the goal of X").
2. Relative weight: what is foregrounded and what is minor. Don't turn a negated item into an added one ("not A but B" into "A and also B") or reorder a ranking. Keep the terms of a comparison.
3. Assertion strength: an assertion stays asserted, a guess stays a guess. Don't strengthen or weaken hedges.
4. Sentence function: fact, opinion, request, rule, plan, hypothesis, hearsay, figure of speech. None of them may change type. Hearsay doesn't become fact, an opinion doesn't become a flat claim, a request doesn't become a description, a completed change doesn't read as a plan.

If a sentence can't be fixed without changing one of these, leave it as written and ask instead.

### Add nothing

The only sources are the original text, the request, provided material, and the conversation context (the user's messages, files opened, command output). General knowledge, your own earlier summaries, and plausible guesses are not sources.

- No invented actors, causes, conditions, numbers, examples, or terms.
- Don't narrow a vague word into a specific fact. If "the boundary" or "the mechanism" is unclear, keep the claim and ask what it refers to.
- Don't carry a qualifier from one sentence into another that lacked it.
- Unsourced attributions ("some people say") stay as written; don't invent the who or how many. Ask about the source only when it changes how the claim reads.
- Missing information stays missing. Something the source calls "TBD" or "under investigation" stays that way.

### Leave natural text alone

Over-editing is the main failure mode. Fix only the spots where you can name the problem.

- Keep idioms that predate AI (if you'd find the phrase in pre-2022 human writing, it stays).
- Keep deliberate writer voice: an essay's metaphors, a novel's rhythm, a promo piece's enthusiasm.
- Keep lists whose items are genuinely parallel (independent changes, steps, owner/result pairs). Don't flatten them into paragraphs just because lists look AI-ish.
- Keep negations that carry meaning (correcting a likely misreading).
- Keep the register: plain/polite (常体/敬体) and formal/casual don't change unless asked.
- Never touch quoted text, titles, proper names, UI labels, identifiers, or code.

### Process

Drafting:

1. Write the text.
2. Do one self-audit pass against the language file, fixing only what you can name.

Editing someone's text:

1. Rewrite.
2. Re-read source and result side by side for the four meaning axes, and check that nothing was added.
3. Return the rewritten text, then a short "What changed" list (変えたところ in Japanese), one line per change.
4. Add at most 2 questions for things you couldn't resolve (an unclear referent, an unknown source, a claim you left as written because fixing it would change its meaning).

Never put editorial notes inside the text itself: no "(needs confirmation)", 【要確認】, or inline comments. Notes go in the list after the text. If the user asked for the text only, return just the text.
