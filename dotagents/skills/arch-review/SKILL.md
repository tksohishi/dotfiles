---
name: arch-review
description: Shell out to Claude Fable at xhigh effort (headless `claude -p`, read-only) for an adversarial review of the purpose, design and architecture of a plan or change: is it the right problem, does it serve the user's actual goal, what simpler or more conventional design would work, what it locks in, and what to cut. Implementation details (bugs, edge cases, tests, API usage) belong to /impl-review, not here. Use when the user says "/arch-review", "design review", "arch review", "Fable でレビュー", "設計をレビュー", before presenting a plan in plan mode, or before building anything whose direction would be costly to reverse (new architecture, data model, public interface, a new tool or service).
---

# Design Review

Shell out to **Claude Fable** so a stronger model questions the direction of the current session's plan or change before effort goes into details. The reviewer reads the repo fresh. It shares a model family with the session, so it shares more blind spots than a reviewer from another vendor would; the prompt fights that anchoring by giving it the user's words and the artifact, never the session's argument for the design.

Run it on the plan, before code exists, when the direction is still cheap to change. `/impl-review` covers the details once the design is settled.

## When to use

Invoke when the user asks, in plan mode before presenting a plan, or proactively before building a new architecture, data model, public interface, or tool. Skip for changes whose design is dictated by the request (a bug fix, a rename, a config tweak). Each review takes several minutes and draws on the Fable quota.

## Prompt construction (do this every run)

1. **Context paths.** List the files the reviewer should read: `AGENTS.md` / `CLAUDE.md`, `README.md`, `DESIGN.md` / `ARCHITECTURE.md` if present, and the 2-5 existing files the plan touches or competes with. The reviewer will not see this conversation.
2. **The artifact.** A draft plan that only exists in the conversation goes to `<root>/tmp/arch-review/<stamp>-plan.md` first; a change under review is a commit range or `git diff`. Point to it; don't paste long content.
3. **The user's goal.** Quote the user's request verbatim, plus any constraints they stated. Add the inferred intent in one sentence, labeled as inferred. Leave out the session's reasoning for the chosen design; the reviewer has to reach its own view from the artifact.
4. **Already decided.** List decisions the user made explicitly, so the reviewer doesn't relitigate them. A reviewer who thinks one of them is wrong may say so once, as a CONCERN.
5. **The user's note.** When the user adds one (`/arch-review` followed by text), pass it verbatim under its own heading, labeled as the user's.

Keep the prompt under ~2KB. Skeleton:

```
You are reviewing the design of a plan or change produced by another AI
assistant (Claude) for the {PROJECT_NAME} project. Review the direction, not
the details.

Read first: {paths}
Under review: {plan path or commit range}

## The user's request
{verbatim quote; constraints; one inferred-intent sentence labeled as inferred}

## Decided by the user
{explicit decisions, or "none"}

## Questions
- Problem: is this the actual problem, or a symptom or proxy of it? Would
  solving it as framed meet the user's goal?
- Simplest design: what is the least machinery that would work? Name 1-2
  concrete alternatives (simpler, more conventional, or already used in this
  repo) and when each beats this one.
- Fit: does it match how this codebase already does similar things?
- Lock-in: what does it make hard to reverse or change later (data shapes,
  interfaces, dependencies, naming)?
- Scope: what should be cut, deferred, or is missing for the goal?
- External dependencies: for each library, API or service the plan integrates,
  read its official docs (`ctx7 library` then `ctx7 docs`, else the vendor's
  site). Does the design follow the documented integration model, or fight it
  (a built-in feature it reimplements, a deprecated path, a limit or pricing
  rule that breaks it)?

Out of scope: bugs, edge cases, tests, style, per-call API correctness. Mention
one only if it proves the design wrong.

## Constraints
- Output ≤ 650 words. Read narrowly: `rg -l`, `git diff --stat`, file ranges.

## Output format
Start with this section, written before judging anything:
    ## Understanding
    - Current structure: how the parts this touches work today (2-3 lines)
    - The plan: what it changes, in your own words (2-3 lines)
    - Expected shape: what a design for this goal should look like (2-3 lines)

Then, for each finding, tie it to that section (e.g. "adds a second store
where the expected shape has one"):
    [BLOCKER | CONCERN | NIT] <one-line title>
    <2-4 lines: what is wrong with the direction, and the alternative>
    Location: <plan section or path>

End with one verdict line:
    VERDICT: Proceed
or
    VERDICT: Rethink before building
```

## Run

```bash
mkdir -p <root>/tmp/arch-review
claude -p --session-id <uuid> --add-dir <root> --model fable --effort xhigh --permission-mode dontAsk --disallowedTools "Edit Write NotebookEdit" > <root>/tmp/arch-review/<stamp>.md <<'PROMPT'
{the assembled prompt}
PROMPT
```

`<root>` is `git rev-parse --show-toplevel` (`pwd` outside a git repo), `<stamp>` is `date +%Y%m%d-%H%M%S` followed by `-<topic>` (a 2-4 word kebab-case slug of the task, e.g. `20261106-104931-ci-gate-paths`), so parallel sessions never share a file, and `<uuid>` is `uuidgen | tr A-Z a-z`; run all three first and write them literally into the path. The review lands in the project's `tmp/` because the background task's output file sits in a per-session temp directory that does not survive; read findings from the saved file. `--add-dir <root>` lets Fable read the project even when the session started elsewhere; it does not move relative paths, so every path in the prompt is absolute under `<root>`.

The prompt must come over stdin: `--disallowedTools` takes a variadic list and swallows a positional prompt as tool names. `dontAsk` denies any tool call not already allowed by settings, so the reviewer can read and run allowed read-only commands but cannot write. Quote the delimiter and keep any body line from being exactly `PROMPT`. Run it with `run_in_background: true`; don't poll.

## Rebuttal rounds

The first round stays a cold read; the follow-up is a conversation with the same reviewer, which keeps its own thread.

Start one when you disagree with any BLOCKER or CONCERN, or when the user asks you to put a point to the reviewer. Send only what is new since the last round, each part labeled with who said it:

- your rebuttal per disputed finding, quoting its title, answering the point with evidence (a file path, a measurement, a constraint the reviewer missed), not with the design reasoning withheld from round one
- the user's words, verbatim, when they weighed in
- paths to anything changed or newly relevant, never pasted content

Ask the reviewer to answer each disputed finding with `HOLD` or `CONCEDE` and one line why.

```bash
claude -p --resume <uuid> --add-dir <root> --model fable --effort xhigh --permission-mode dontAsk --disallowedTools "Edit Write NotebookEdit" > <root>/tmp/arch-review/<stamp>-r2.md <<'PROMPT'
{the rebuttal}
PROMPT
```

At most two rebuttal rounds (`-r2`, `-r3`); after that, the remaining disagreement goes to the user.

## Reporting back to the user

1. Print the reviewer's Understanding section first, flagging any line where it misread the plan or the codebase (a misread puts the findings that rest on it in doubt). Then print the VERDICT line, then findings grouped BLOCKER, CONCERN, NIT, each with whether you agree and why. Don't auto-capitulate, and don't defend the plan by restating the reasoning the reviewer was not given; answer the point. After rebuttal rounds, list conceded findings as resolved, one line each.
2. Design findings change direction, design or scope, so they are the user's call, not yours. Apply only ones that are plainly a detail (a missing step, a wrong file). For the rest, including every finding the reviewer held after rebuttal, list each with both positions in the reply first, then ask with AskUserQuestion (at most 4 per call): quote the reviewer's point verbatim, then your position and the trade-off, with the reviewer's alternative and the current plan as the options.
3. Revise the plan with the user's answers before presenting it or building.
4. Log one line once findings are settled; `user_overrode` counts answers where the user sided against your position, `conceded` the findings the reviewer dropped in rebuttal rounds.

```bash
jq -nc '{date: (now | todate), project: "<repo dir name>", skill: "arch-review", reviewer: "claude", model: "claude-fable-5-1", findings: {blocker: 0, concern: 0, nit: 0}, accepted: 0, rejected: 0, user_overrode: 0, rounds: 1, conceded: 0, seconds: 0}' >> ~/.local/state/review/log.jsonl
```
