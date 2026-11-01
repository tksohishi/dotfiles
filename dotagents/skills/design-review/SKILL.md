---
name: design-review
description: Shell out to Claude Fable at xhigh effort (headless `claude -p`, read-only) for an adversarial review of the purpose, design and architecture of a plan or change: is it the right problem, does it serve the user's actual goal, what simpler or more conventional design would work, what it locks in, and what to cut. Implementation details (bugs, edge cases, tests, API usage) belong to /impl-review, not here. Use when the user says "/design-review", "design review", "Fable でレビュー", "設計をレビュー", before presenting a plan in plan mode, or before building anything whose direction would be costly to reverse (new architecture, data model, public interface, a new tool or service).
---

# Design Review

Shell out to **Claude Fable** so a stronger model questions the direction of the current session's plan or change before effort goes into details. The reviewer reads the repo fresh. It shares a model family with the session, so it shares more blind spots than a reviewer from another vendor would; the prompt fights that anchoring by giving it the user's words and the artifact, never the session's argument for the design.

Run it on the plan, before code exists, when the direction is still cheap to change. `/impl-review` covers the details once the design is settled.

## When to use

Invoke when the user asks, in plan mode before presenting a plan, or proactively before building a new architecture, data model, public interface, or tool. Skip for changes whose design is dictated by the request (a bug fix, a rename, a config tweak). Each review takes several minutes and draws on the Fable quota.

## Prompt construction (do this every run)

1. **Context paths.** List the files the reviewer should read: `AGENTS.md` / `CLAUDE.md`, `README.md`, `DESIGN.md` / `ARCHITECTURE.md` if present, and the 2-5 existing files the plan touches or competes with. The reviewer will not see this conversation.
2. **The artifact.** A draft plan that only exists in the conversation goes to `tmp/design-review/plan.md` first; a change under review is a commit range or `git diff`. Point to it; don't paste long content.
3. **The user's goal.** Quote the user's request verbatim, plus any constraints they stated. Add the inferred intent in one sentence, labeled as inferred. Leave out the session's reasoning for the chosen design; the reviewer has to reach its own view from the artifact.
4. **Already decided.** List decisions the user made explicitly, so the reviewer doesn't relitigate them. A reviewer who thinks one of them is wrong may say so once, as a CONCERN.

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

Out of scope: bugs, edge cases, tests, style, API correctness. Mention one only
if it proves the design wrong.

## Constraints
- Output ≤ 500 words. Read narrowly: `rg -l`, `git diff --stat`, file ranges.

## Output format
For each finding:
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
claude -p --model fable --effort xhigh --permission-mode dontAsk --disallowedTools "Edit Write NotebookEdit" <<'PROMPT'
{the assembled prompt}
PROMPT
```

The prompt must come over stdin: `--disallowedTools` takes a variadic list and swallows a positional prompt as tool names. `dontAsk` denies any tool call not already allowed by settings, so the reviewer can read and run allowed read-only commands but cannot write. Quote the delimiter and keep any body line from being exactly `PROMPT`. Run it with `run_in_background: true`; don't poll.

## Reporting back to the user

1. Print the VERDICT line, then findings grouped BLOCKER, CONCERN, NIT, each with whether you agree and why. Don't auto-capitulate, and don't defend the plan by restating the reasoning the reviewer was not given; answer the point.
2. Design findings change direction, design or scope, so they are the user's call, not yours. Apply only ones that are plainly a detail (a missing step, a wrong file). For the rest, list every one with your position in the reply first, then ask with AskUserQuestion (at most 4 per call): quote the reviewer's point verbatim, then your position and the trade-off, with the reviewer's alternative and the current plan as the options.
3. Revise the plan with the user's answers before presenting it or building.
4. Log one line once findings are settled; `user_overrode` counts answers where the user sided against your position.

```bash
jq -nc '{date: (now | todate), project: "<repo dir name>", skill: "design-review", reviewer: "claude", model: "claude-fable-5-1", findings: {blocker: 0, concern: 0, nit: 0}, accepted: 0, rejected: 0, user_overrode: 0, seconds: 0}' >> ~/.local/state/review/log.jsonl
```
