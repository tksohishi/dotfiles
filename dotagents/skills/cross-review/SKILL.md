---
name: cross-review
description: Shell out to OpenAI Codex (GPT-6-Astra at xhigh, via `codex exec`) for an adversarial second-opinion review of non-code work the current session produced - drafts, forum comments, rationales, analyses, reports, recommendations. It checks every load-bearing claim against its primary source, the reasoning against the evidence, and the draft against what the reader needs. Code changes belong to /impl-review, plans and architecture to /arch-review. Use when the user says "/cross-review", "/codex-review", "cross review", "別の LLM で review", "コーデックスでチェック" on a draft, "/cross-review fable" or "/cross-review argon" (Fable at xhigh or Gemini 4 Argon reviewing in parallel), "Fable でも", "Gemini でも", when a project skill calls for a cross-review gate, or before publishing anything a wrong fact or misread source would embarrass (public posts, votes, financial or governance claims, emails).
---

# Cross Review

An independent model audits a piece of writing or analysis the session produced. The reviewer reads the files fresh, with no memory of what this session verified, so it can catch a misread source or an inference the author talked themselves into. Its job is to find errors, not to approve.

## Compose the prompt

The reviewer never sees this conversation; everything it needs comes from the prompt and the files it names.

1. **Context.** List the paths it must read first: the project's `AGENTS.md`, the files a project skill names as context (user profile, org notes), the draft itself, and the primary sources the draft relies on (thread files, data, images, linked docs). Give paths; don't paste content.
2. **Goal.** Quote the user's request verbatim, then state who reads the result and what decision it feeds (a vote, a reply, a purchase).
3. **Already verified.** List what this session already checked against sources, so the reviewer spends its effort elsewhere.
4. **Lenses.** Always include these three:
   - **Claims vs primary sources.** For each number, date, amount, quote, attribution and rule: find it in the primary source, not in someone's restatement of it. Mark each as VERIFIED (with the file path or URL and the exact location), CONTRADICTED (with what the source says) or UNVERIFIABLE.
   - **Reasoning.** Conclusions the evidence doesn't support, overclaiming, a counterargument the reader will raise that the draft ignores, a stale premise (a later post or version superseding the one cited).
   - **Reader fit.** Does it answer what the reader needs, in the register the venue expects, without tone that undercuts the argument?
   Add the project's own known failure modes from its `AGENTS.md` (for example a source-precedence rule) as a fourth lens.
5. **Output rules.** Paste this block at the end:

```
Rules:
- Cite the exact file path and line, or URL, for every VERIFIED or CONTRADICTED mark. A check from memory does not count.
- Read narrowly: rg -n for the claim, then the surrounding lines. Do not read whole data directories.
- Do not edit any file.
- Output at most 600 words.

Format, findings grouped by severity:
BLOCKER: wrong or contradicted claim, or a conclusion the evidence does not support
CONCERN: unverifiable claim, missing counterargument, misleading framing
NIT: wording, tone, ordering
Each finding: the quoted sentence from the draft, what is wrong, the source, and the fix.
End with one line: VERDICT: Ready | Fix first
```

## Run

`<stamp>` is `date +%Y%m%d-%H%M%S`, run first and written literally into every path below. Write the assembled prompt to `tmp/cross-review/<stamp>-prompt.md`, then:

```bash
codex exec -m gpt-6-astra -c model_reasoning_effort=xhigh -s read-only -o tmp/cross-review/<stamp>-codex.md - < tmp/cross-review/<stamp>-prompt.md
```

`-o` saves only the reviewer's final message to the project's `tmp/`; the background task's own output sits in a per-session temp directory that does not survive. `-s read-only` keeps the reviewer from editing; web search still works for sources outside the repo. Run with `run_in_background: true`; don't poll.

### Extra reviewers, only when asked

Add a reviewer only when the user names it (`/cross-review fable`, `/cross-review argon`, "Fable でも", "Gemini でも") or a project skill's gate names it. Each extra model catches different misses, at the cost of its own quota. Run every named reviewer in the background at the same time as Codex, all on the same prompt file.

**Fable at xhigh.** Worth it on high-stakes analysis; from a Claude session it is a deeper reading by the same model family, not a different lineage.

```bash
claude -p --model fable --effort xhigh --permission-mode dontAsk --disallowedTools "Edit Write NotebookEdit" < tmp/cross-review/<stamp>-prompt.md > tmp/cross-review/<stamp>-fable.md
```

The prompt must come over stdin: `--disallowedTools` takes a variadic list and swallows a positional prompt as tool names. `dontAsk` denies any tool not already allowed by settings, so Fable reads the repo but may not reach the web; give it local copies of web sources where they exist.

**Gemini 4 Argon.** The Google AI Pro allowance is small (a full review uses several percent of the weekly bucket).

1. Check quota (free): `agy -p /usage --output-format json | jq '.command.data.groups[] | select(.name=="Gemini 4 Argon") | .buckets[0].remaining_fraction'`. Below `0.25`, skip Argon and tell the user.
2. Argon reads files but cannot run shell commands (headless `--mode plan` refuses all of them), so the prompt must name file paths rather than commands to run.
3. `-p` ignores stdin, so pipe the prompt in as stream-json:

```bash
jq -Rsc '{event:"user",message:{content:[{type:"text",text:.}]}}' tmp/cross-review/<stamp>-prompt.md |
  agy --model gemini-4-argon-high --mode plan --input-format stream-json --output-format stream-json -p "" \
  > tmp/cross-review/<stamp>-argon.ndjson
```

4. Read it with `jq -r 'select(.event=="result") | .result | .status, .response' tmp/cross-review/<stamp>-argon.ndjson`. An empty `response` is a failed run even when `status` is `SUCCESS`; check `select(.event=="step_update") | .step_update | select(.state=="ERROR")` for the cause and report it rather than retrying blindly.

## Report back

1. Read each reviewer's file. A missing or empty one means that run failed; check the tail of its task output for the error.
2. Print each VERDICT line, then findings grouped BLOCKER, CONCERN, NIT, each with whether you agree. With several reviewers, merge duplicates and note which reviewers raised each finding; a point only one model raised still counts.
3. Verify every source the reviewer cites before acting on it: open the file location or URL and confirm it says what the reviewer claims. A citation that doesn't hold up makes the finding uncertain, not accepted.
4. Fix agreed BLOCKERs and CONCERNs in the draft before showing it. Where you disagree, say why; don't auto-capitulate. A finding that changes the draft's position or recommendation goes to the user with your view, since that is their call.
5. Log one line per reviewer once findings are settled (`reviewer`/`model`: `codex`/`gpt-6-astra`, `claude`/`claude-fable-5-1`, or `agy`/`gemini-4-argon-high`):

```bash
jq -nc '{date: (now | todate), project: "<repo dir name>", skill: "cross-review", reviewer: "codex", model: "gpt-6-astra", findings: {blocker: 0, concern: 0, nit: 0}, accepted: 0, rejected: 0, user_overrode: 0, seconds: 0}' >> ~/.local/state/review/log.jsonl
```
