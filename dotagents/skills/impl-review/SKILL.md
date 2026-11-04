---
name: impl-review
description: Shell out to OpenAI Codex (GPT-6-Astra at xhigh, via `codex exec`) for an adversarial second-opinion review of the implementation details the current session produced. The prompt is composed fresh per invocation — project context, the user's actual goal, what was produced, and risk categories specific to this project's domain. Every review hunts correctness bugs and edge cases, audits test coverage, and checks newly used APIs against official docs, aiming at the details earlier agents missed. Purpose, design and architecture belong to /arch-review, not here. Use when the user says "/impl-review", "impl review", "codex review", "Astra でチェック", "コーデックスでチェック", "別の LLM で review", or before committing code where errors are costly (security-sensitive code, API contracts, anything irreversible). Drafts, analyses and other non-code work belong to /cross-review. The reviewer's job is to catch errors from first principles, not rubber-stamp "done".
---

# Impl Review

Shell out to **OpenAI Codex** so an independent model from another vendor audits the details of the current session's recent work. The reviewer reads the repo fresh — no memory of what the current session verified, no anchoring on its framing. That is the point: adversarial second-pair-of-eyes, not a peer reviewer who already trusts the author.

This review takes the design as settled. Whether the work solves the right problem, the architecture, and the alternatives are `/arch-review`'s job; run that first, on the plan, when the direction is still open.

## When to use

Invoke when the user explicitly asks (`/impl-review`, "codex review", "別の LLM で review") OR proactively before:

- Committing changes where a wrong fact / number / API call would cost the user real money, time, or trust
- Publishing public-facing copy with factual, financial, regulatory, or affiliate claims
- Shipping security-sensitive code (auth, crypto, secret handling, IPC, untrusted-input parsing)
- Merging large refactors where reviewer fatigue could miss a subtle regression
- Closing a long task where Claude has been making judgment calls without external verification

Skip for trivial edits (layout tweaks, comment changes, throwaway scripts, single-line typo fixes). Each review costs ~1-5 minutes and several thousand tokens.

## Prompt construction (do this every run)

The whole point of this generalized skill: **the prompt is composed fresh per invocation**, not loaded as a static template. Walk these steps before invoking codex.

### Step 1 — Discover project context

Read whichever of these exist at the project root, in order, before drafting the prompt:

- `AGENTS.md` / `CLAUDE.md` (often symlinked together so both tools share context)
- `README.md` / `README`
- `DESIGN.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md` if present
- Your global personal instructions are already loaded into your context — no need to re-read

The reviewer will not see this conversation. It must rediscover the project from files. List the **exact paths** the reviewer should read in the prompt (Step 4) so it does not have to guess.

If the project is brand new or has no AGENTS.md, the user's intent has to come from this conversation — quote it verbatim in Step 4.

### Step 2 — Capture what's under review

List the specific surface to audit:

- Uncommitted diff (`git status --short` + `git diff --stat`)
- Just-committed work (specific commit SHAs)
- Specific files the user pointed at
- Drafts in known directories (`content/drafts/`, `proposals/`, etc.)

For UI / visual / generated-image work, **point to the rendered artifact** (PNG, PDF, deployed URL), not just the source. Source alone misses layout / wrap / density issues.

For long outputs (drafts, specs, posts), do not paste the whole content into the prompt — tell the reviewer the path and have it `Read` the file itself. Pasting bloats the prompt and the reviewer's read of the live file is more authoritative anyway.

Also list what has already been reviewed or verified this session (subagent reviews, `/arch-review`, `/code-review`, tests run, sources fetched). The reviewer skips that ground and digs for what those passes missed.

### Step 3 — Pick risk categories

Two lenses go into every prompt; they are the reason to bring in a second model:

- **Edge cases**: empty / huge / malformed input, concurrency and re-entry, partial failure and retries, first run vs. upgrade, platform and locale differences, interactions with existing features. Each one names the concrete input or state, the resulting behavior, and how often that input occurs in real use: common, plausible, or rare.
- **Test coverage**: which behaviors of the change have no test, which tests would still pass if the code were wrong, which edge cases above lack a test. Name the missing test cases, not just "add tests".

Add a third lens when the diff calls an external API (a library function, CLI flag, SDK method, platform or service endpoint, config key) the code didn't use before, or uses an existing one in a drastically different way (new arguments or options, a different calling context, relying on behavior it didn't rely on before):

- **Official docs check**: list each such method by name in the prompt and have the reviewer check it against the official documentation: whether it exists in the version the project pins, its signature and defaults, its return and error behavior, deprecations, and documented caveats the code ignores. The reviewer cites the doc URL or `ctx7` result for every finding; a claim checked only against memory doesn't count. Picking the methods stays with you, since you know what the change introduced; the reviewer adds any you missed.

Add **1-3** project-specific categories on top. Don't enumerate all of them — a 7-section adversarial prompt produces a 5000-word review that wastes context. Tailor.

Common categories (pick what fits):

- **Correctness** — logic errors, off-by-one, wrong API usage, race conditions, unhandled error paths
- **Security** — injection, secret exposure, unsafe defaults, privilege escalation, untrusted input crossing trust boundaries
- **Factual accuracy** — claims about products / prices / rates / specs / API behavior. Demand source citations (issuer page > aggregator > blog).
- **API contracts** — breaking changes vs prior version, schema drift, missing migration, version skew
- **Performance** — O(n²) hot paths, N+1 queries, memory leaks, unnecessary network calls, missing pagination
- **Documentation** — stale docs, README mismatches code, missing examples, undocumented breaking change
- **Style / convention** — code patterns inconsistent with rest of the codebase (read 2-3 sibling files first)
- **UX** — error messages, edge cases, accessibility, regressions in the golden path
- **Language quality** — for non-English copy: unnatural translation tone, jargon misuse, terminology consistency, target-reader fit
- **Visual quality** — slide / image / UI rendering: heading wraps, font hierarchy, color semantics, asymmetric layouts (require rendered PNG, not source)
- **Compliance** — FTC disclosure, license headers, GDPR / CCPA / HIPAA / SOC2 implications, content licensing
- **Domain-specific** — anything the project's `AGENTS.md` defines as failure mode (transfer-direction grammar in CCM, etc.)

If the project has known historical failure modes (past incidents, recurring bug classes), pull those forward into a "known traps" section.

### Step 4 — Assemble the prompt

Use this skeleton. Substitute the bracketed sections with what you found in Steps 1-3. Keep the whole prompt under ~3KB; long prompts dilute the reviewer's focus. Describe hostile input in plain code-review terms ("untrusted input", "a crafted request"): Codex refuses prompts that ask it to imagine a "malicious payload" or "adversarial payload" as a cyber request. The Run section passes it to the reviewer via a quoted heredoc — no intermediate file.

```
You are auditing work produced by another AI assistant (Claude) for the {PROJECT_NAME} project.

Before reviewing, READ the following for context:
{LIST OF ABSOLUTE OR REPO-RELATIVE PATHS — AGENTS.md, README, DESIGN.md, the
files under review, etc.}

## The user's actual goal
{One paragraph. Quote the user's exact request verbatim, then state the
inferred underlying intent. The reviewer needs both — what they literally
asked AND what success looks like.}

## What Claude produced
{One paragraph. List the files / commits / artifacts under review. For drafts,
give the path and tell the reviewer to Read it. For diffs, mention the
range (`HEAD~3..HEAD` or `git diff main`).}

## Review from first principles

Your job is not to confirm completion. Your job is to catch errors that
would {COST WHAT — readers' money, security incident, broken API consumers,
regulatory fine, etc.}. Be adversarial. If a claim cannot be verified from
the cited source, flag it. The design direction is settled; raise a design
problem only when it causes a concrete bug.

## Already reviewed
{What earlier passes covered (design review, subagent reviews, /code-review,
tests run, verified sources). Do not repeat their findings; look for what they
missed, especially in the details.}

## Edge cases
{3-6 project-specific edge cases to probe. For each issue found, give the
concrete input/state, the resulting wrong behavior, and how often that input
occurs in real use (common / plausible / rare).}

## Test coverage
{Which changed behaviors and edge cases have no test; which tests would pass
if the code were wrong. Name the missing test cases.}

## Official docs check
{Only when Step 3 adds this lens. List the new or drastically changed external
methods (name, file:line, the version the project pins). Check each against its
official documentation: `ctx7 library <name>` then `ctx7 docs <id> "<query>"`,
plus `--help` for CLIs; fetch the vendor's docs only if ctx7 has no hit. Flag
wrong signatures, unsupported options, behavior the docs contradict,
deprecations, and caveats the code ignores. Cite the doc URL or ctx7 id for
each. Add methods the list missed.}

{1-3 project-specific RISK SECTIONS from Step 3, each with 3-6 specific
things to check. Tailor wording to project — do not copy generic boilerplate.}

## Known traps for this project
{Optional. List historical failures if AGENTS.md or commit history surfaces them.
Skip if nothing specific.}

## Constraints
- Output ≤ 600 words total. Brevity over completeness.
- Do not retry the same URL more than 2 times. If a source 403s twice, note
  the failure and move on.
- Do not re-verify facts already labeled VERIFIED in this prompt.
- Read narrowly; every byte of command output fills your context. Start
  diffs with `git diff --stat`, then `git diff -- <path>` per file. Read
  files in ranges (`sed -n 'A,Bp'`, ~80 lines at a time) found via
  `rg -n`, never `cat` or `nl -ba` several files at once. Bound searches
  with `rg -l`, `-m N`, `--max-columns 200`, or `| head`.

## Output format

For each finding:

    [BLOCKER | CONCERN | NIT] <one-line title>
    <2-4 lines of reasoning>
    Location: path/to/file:line (or "draft caption", etc.)
    Source: <URL or path — REQUIRED for any factual correction>

End with one verdict line:
    VERDICT: Ship it
or
    VERDICT: Do not ship until BLOCKERs resolved

Be blunt. A false positive costs a minute; a false negative costs
{whatever the project cares about}.
```

## Run

`codex` is on PATH via shell inheritance — call it directly, no `mise exec --` wrapper. Feed the Step 4 prompt over stdin via a quoted heredoc:

```bash
mkdir -p <root>/tmp/impl-review
codex exec -C <root> -m gpt-6-astra -c model_reasoning_effort=xhigh -o <root>/tmp/impl-review/<stamp>.md - <<'PROMPT'
{the assembled prompt from Step 4}
PROMPT
```

`<root>` is `git rev-parse --show-toplevel` (`pwd` outside a git repo) and `<stamp>` is `date +%Y%m%d-%H%M%S`; run both first and write them literally into the path. `-o` saves the reviewer's final message (the findings, without tool-call traces) to the project's `tmp/`, because the background task's output file sits in a per-session temp directory that does not survive. `-C <root>` makes the project the reviewer's working root wherever the session started; still give every path in the prompt as an absolute path under `<root>`.

The model and effort are pinned here because `~/.codex/config.toml` sets a different daily model at medium effort. The `-` arg tells `codex exec` to read the prompt from stdin. The heredoc ends at the delimiter, so EOF arrives and the call doesn't hang.

**Don't combine `codex exec review --uncommitted` with a custom prompt.** Those flags are mutually exclusive (`error: the argument '--uncommitted' cannot be used with '[PROMPT]'`). Use plain `codex exec` with a custom prompt — the project-specific adversarial framing is the value-add. The built-in `review` mode is fine for generic code review but skips everything Steps 1-3 composed.

**Heredoc hygiene.** Quote the delimiter (`<<'PROMPT'`) so nothing in the prompt body is shell-expanded, and make sure no line of the body is exactly `PROMPT`. If the prompt is unusually long or you want it inspectable/re-runnable after the fact, writing it to `<root>/tmp/impl-review/prompt.md` and redirecting (`< <root>/tmp/impl-review/prompt.md`) still works.

**Run in the background.** Reviews take 1-5 minutes. Use `run_in_background: true` on the Bash tool call and continue with other work; you'll be notified on completion. Don't poll, don't sleep.

## Reporting back to the user

When the reviewer returns:

1. **Read the `-o` file, not the task output.** The task output holds 100KB+ of tool-call traces; the `-o` file holds only the findings. If the `-o` file is missing or empty (the run failed), check the tail of the task output for the error.
2. Print the reviewer's VERDICT line.
3. Group findings: BLOCKERs first, then CONCERNs, then NITs.
4. For each finding, state whether you agree.
5. **Verify reviewer-cited URLs before accepting them.** The reviewer can hallucinate sources. If it says "the issuer page says X", fetch the page and confirm. If the URL 404s or doesn't say what was cited, treat that finding as uncertain.
6. If BLOCKERs are valid, fix before reporting the work as done. Do not commit / publish until resolved. A BLOCKER whose fix would change the direction, design or scope goes to the user first, per step 8.
7. If you disagree with the reviewer, say why — don't auto-capitulate. The reviewer's verdict is not the last word; you remain responsible for the output.
8. Apply findings you agree with that fix a detail (a missing test, a wrong number, an edge case users will hit) without asking, one summary line each. An edge case you judge rare, from the reviewer's likelihood and what you know of real usage, with low impact (no data loss, secret exposure, money, or broken golden path) gets its line as "noted, not fixed" and no code change: the fix is code every reader pays for against a bug almost nobody meets. Rare but severe is fixed, or goes to the user if the fix changes design or scope. Put a finding to the user only when it is contentious: you disagree with it, or it would change the direction, design or scope rather than a detail. Steps 2-4 go out as reply text first, listing every contentious finding with its evidence and your position; a question never stands in for that list, since the user cannot pick between options whose findings they have not seen. Then ask with AskUserQuestion, one question per contentious finding (AskUserQuestion takes at most 4 per call): quote the reviewer's point verbatim, then your position and the trade-off, with the reviewer's fix and yours as the options. A reviewer who misread the plan is the case this catches, so don't paraphrase their point into agreement.
9. Log one line to `~/.local/state/review/log.jsonl` (create the directory if missing) once findings are settled, after the user's answers to any step 8 questions, so reviewers can be compared across projects later. Counts come from your step 4 judgments (a "noted, not fixed" finding is accepted); `user_overrode` is step 8 answers where the user sided against your position.

```bash
jq -nc '{date: (now | todate), project: "<repo dir name>", skill: "impl-review", reviewer: "codex", model: "gpt-6-astra", findings: {blocker: 0, concern: 0, nit: 0}, accepted: 0, rejected: 0, user_overrode: 0, seconds: 0}' >> ~/.local/state/review/log.jsonl
```

## Notes

- The reviewer sees the repo fresh from disk. Uncommitted work that isn't even saved to disk won't be visible — write the file first.
- For projects with a domain-heavy review (financial fact-checking, FTC compliance, language quality, etc.), prefer a project-local `impl-review` skill with the project-specific prompt baked in at `.claude/skills/impl-review/SKILL.md`. This global skill is the fallback for projects that don't have one.
