---
name: cross-review
description: Shell out to the OTHER LLM agent for an adversarial second-opinion review of work the current session has produced. From Claude → invoke OpenAI Codex (`codex exec`); from Codex → invoke Claude (`claude -p`). The prompt is composed fresh per invocation — project context, the user's actual goal, what was produced, and risk categories specific to this project's domain. Use when the user says "/cross-review", "/codex-review", "/claude-review", "cross review", "コーデックスでチェック", "クロードでチェック", "別の LLM で review", or before committing/publishing work where errors are costly (financial claims, security-sensitive code, API contracts, public-facing copy, anything irreversible). The reviewer's job is to catch errors from first principles, not rubber-stamp "done".
---

# Cross Review

Shell out to **the other LLM agent** so an independent model audits the current session's recent work. The reviewer reads the repo fresh — no memory of what the current session verified, no anchoring on its framing. That is the point: adversarial second-pair-of-eyes, not a peer reviewer who already trusts the author.

The skill is symmetric:

- **You are Claude Code** → invoke **OpenAI Codex** via `codex exec`.
- **You are OpenAI Codex CLI** → invoke **Claude** via `claude -p`.

You (the agent reading this skill) know which side you are. Pick the matching branch in [Run](#run) below. Everything outside Run — when to use, prompt construction, output format, reporting — is identical for both branches.

## When to use

Invoke when the user explicitly asks (`/cross-review`, `/codex-review`, "cross review", "別の LLM で review") OR proactively before:

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

### Step 3 — Pick risk categories

Pick the **2-5** most relevant categories for this project. Don't enumerate all of them — a 7-section adversarial prompt produces a 5000-word review that wastes context. Tailor.

Common categories (pick what fits):

- **Correctness** — logic errors, off-by-one, wrong API usage, race conditions, unhandled error paths
- **Security** — injection, secret exposure, unsafe defaults, privilege escalation, untrusted input crossing trust boundaries
- **Factual accuracy** — claims about products / prices / rates / specs / API behavior. Demand source citations (issuer page > aggregator > blog).
- **API contracts** — breaking changes vs prior version, schema drift, missing migration, version skew
- **Performance** — O(n²) hot paths, N+1 queries, memory leaks, unnecessary network calls, missing pagination
- **Tests** — missing coverage of the change, brittle/over-mocked tests, tests that pass when the code is wrong
- **Documentation** — stale docs, README mismatches code, missing examples, undocumented breaking change
- **Style / convention** — code patterns inconsistent with rest of the codebase (read 2-3 sibling files first)
- **UX** — error messages, edge cases, accessibility, regressions in the golden path
- **Language quality** — for non-English copy: unnatural translation tone, jargon misuse, terminology consistency, target-reader fit
- **Visual quality** — slide / image / UI rendering: heading wraps, font hierarchy, color semantics, asymmetric layouts (require rendered PNG, not source)
- **Compliance** — FTC disclosure, license headers, GDPR / CCPA / HIPAA / SOC2 implications, content licensing
- **Domain-specific** — anything the project's `AGENTS.md` defines as failure mode (transfer-direction grammar in CCM, etc.)

If the project has known historical failure modes (past incidents, recurring bug classes), pull those forward into a "known traps" section.

### Step 4 — Assemble the prompt

Use this skeleton. Substitute the bracketed sections with what you found in Steps 1-3. Keep the whole prompt under ~2KB; long prompts dilute the reviewer's focus. The Run section passes it to the reviewer via a quoted heredoc — no intermediate file.

```
You are auditing work produced by another AI assistant ({CURRENT_ASSISTANT}) for the {PROJECT_NAME} project.

Before reviewing, READ the following for context:
{LIST OF ABSOLUTE OR REPO-RELATIVE PATHS — AGENTS.md, README, DESIGN.md, the
files under review, etc.}

## The user's actual goal
{One paragraph. Quote the user's exact request verbatim, then state the
inferred underlying intent. The reviewer needs both — what they literally
asked AND what success looks like.}

## What {CURRENT_ASSISTANT} produced
{One paragraph. List the files / commits / artifacts under review. For drafts,
give the path and tell the reviewer to Read it. For diffs, mention the
range (`HEAD~3..HEAD` or `git diff main`).}

## Review from first principles

Your job is not to confirm completion. Your job is to catch errors that
would {COST WHAT — readers' money, security incident, broken API consumers,
regulatory fine, etc.}. Be adversarial. If a claim cannot be verified from
the cited source, flag it.

{2-5 RISK SECTIONS picked in Step 3, each with 3-6 specific things to check.
Tailor wording to project — do not copy generic boilerplate.}

## Known traps for this project
{Optional. List historical failures if AGENTS.md or commit history surfaces them.
Skip if nothing specific.}

## Constraints
- Output ≤ 600 words total. Brevity over completeness.
- Do not retry the same URL more than 2 times. If a source 403s twice, note
  the failure and move on.
- Do not re-verify facts already labeled VERIFIED in this prompt.

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

Pick the branch that matches your identity. Both binaries are on PATH via shell inheritance — call them directly, no `mise exec --` wrapper. Both branches feed the Step 4 prompt over stdin via a quoted heredoc.

### Branch A — you are Claude Code, invoke Codex

```bash
codex exec - <<'PROMPT'
{the assembled prompt from Step 4}
PROMPT
```

The `-` arg tells `codex exec` to read the prompt from stdin (per `codex exec --help`: "If not provided as an argument (or if `-` is used), instructions are read from stdin"). The heredoc ends at the delimiter, so EOF arrives and the call doesn't hang.

**Don't combine `codex exec review --uncommitted` with a custom prompt.** As of codex 0.x, those flags are mutually exclusive (`error: the argument '--uncommitted' cannot be used with '[PROMPT]'`). Use plain `codex exec` with a custom prompt — the project-specific adversarial framing is the value-add. The built-in `review` mode is fine for generic code review but skips everything Steps 1-3 composed.

### Branch B — you are OpenAI Codex CLI, invoke Claude

```bash
claude -p --model opus <<'PROMPT'
{the assembled prompt from Step 4}
PROMPT
```

`claude -p` reads from stdin when no positional prompt is given, so the heredoc body becomes the prompt. Runs once and prints to stdout, then exits — analogous to `codex exec`. Always pass `--model opus`: without it, `claude -p` inherits the user's session default model, which may be a pricier tier than a review warrants.

### Branch-agnostic guardrails (apply to both)

**Heredoc hygiene.** Quote the delimiter (`<<'PROMPT'`) so nothing in the prompt body is shell-expanded, and make sure no line of the body is exactly `PROMPT`. If the prompt is unusually long or you want it inspectable/re-runnable after the fact, writing it to `tmp/CROSS_REVIEW_PROMPT.md` and redirecting (`< tmp/CROSS_REVIEW_PROMPT.md`) still works — it's just no longer required.

**Run in the background.** Reviews take 1-5 minutes. Use `run_in_background: true` on the Bash tool call and continue with other work; you'll be notified on completion. Don't poll, don't sleep.

## Reporting back to the user

When the reviewer returns:

1. **Read findings only, not the whole transcript.** Reviewer output can be 100KB+ of tool-call traces. `grep -nE 'BLOCKER|CONCERN|NIT|VERDICT' <output-file>` first to find the findings section, then `Read` with `offset`/`limit`. Don't `cat` the whole file — wastes context on retry traces and tool noise.
2. Print the reviewer's VERDICT line.
3. Group findings: BLOCKERs first, then CONCERNs, then NITs.
4. For each finding, state whether you agree.
5. **Verify reviewer-cited URLs before accepting them.** Either model can hallucinate sources. If the reviewer says "the issuer page says X", fetch the page and confirm. If the URL 404s or doesn't say what was cited, treat that finding as uncertain.
6. If BLOCKERs are valid, fix before reporting the work as done. Do not commit / publish until resolved.
7. If you disagree with the reviewer, say why — don't auto-capitulate. The reviewer's verdict is not the last word; you remain responsible for the output.

## Notes

- The reviewer sees the repo fresh from disk. Uncommitted work that isn't even saved to disk won't be visible — write the file first.
- AGENTS.md being symlinked to CLAUDE.md (common pattern) means both tools share project context with no extra wiring.
- For projects with a domain-heavy review (financial fact-checking, FTC compliance, language quality, etc.), prefer a project-local `cross-review` skill with the project-specific prompt baked in — `.claude/skills/cross-review/SKILL.md` for the Claude side, the equivalent location for the other agent. This global skill is the fallback for projects that don't have one.
