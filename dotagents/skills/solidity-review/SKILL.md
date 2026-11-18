---
name: solidity-review
description: Shell out to OpenAI Codex (the newest Astra model at xhigh, via `codex exec`) for a one-pass adversarial security review of Solidity source before it is deployed, on a slimmed version of pashov's solidity-auditor lenses (access control, boundaries, execution trace, flow gaps, invariants, asymmetry, math, trust), with its four judging gates. Use when the user says "/solidity-review", "/smart-contract-review", "コントラクトをレビュー", "Solidity の監査", or when a project rule asks for a security review of a contract's exact source before its deploy. General code goes to /impl-review; a full multi-agent audit is pashov's solidity-auditor itself.
---

# Solidity Review

One codex run audits a contract the way pashov's solidity-auditor (github.com/pashov/skills, `solidity-auditor/references/`) does with twelve agents: the same lenses, cut to the checks that find bugs in a small executor or vault, and the same judging gates, so a finding comes with a proof or is a lead. It costs one review's minutes instead of the auditor's 15 to 45, and gives an independent model's read where /impl-review gives a general one. It does not replace /impl-review or /code-review where a project asks for those; it is the security pass beside them.

## Prompt construction (every run)

1. **Scope.** The exact `.sol` files the deploy sends (named by path, never a glob), and the deployed predecessor when there is one: a diff against it goes to `<root>/tmp/solidity-review/<stamp>-diff.diff` and the reviewer gets both, the whole new source and the diff, so it reviews the contract and knows what moved.
2. **Context files.** `AGENTS.md`, the contract's design doc, its tests, and the off-chain code that builds its calldata or calls it (an encoder, a deploy script, an admin script): a contract's bugs often sit between its packed layout and the code that packs it.
3. **The user's goal and the design decisions.** Quote the user's words on what the contract must do and what they chose (a float held, a role split, an approval kept). A decision is out of scope as a finding unless it causes a concrete loss; the reviewer may name it once as a CONCERN.
4. **Already reviewed.** Earlier passes (/impl-review, /code-review, an auditor run) and what they closed, so the reviewer spends its effort on new ground.
5. **Live facts the code cannot show.** Which external contracts it trusts (routers, pools, hooks) and whether their source is verified; what an approval or a callback exposes. A reviewer cannot read an unverified venue; say so.

Keep the prompt under about 4KB; long material goes in files the reviewer reads.

## The prompt

```
You are auditing Solidity for the {PROJECT} project, written by another AI assistant (Claude), before it is deployed. You
are an attacker: find what loses funds, lets a third party move them, or lets a losing or forged action pass.

Read first: {paths}. In scope: {exact .sol paths}. Changed from the deployed {predecessor}: {diff path}.

## What it must do (the user's words) and what is decided
{quotes; decisions; trusted external contracts and their verification status}

## Already reviewed
{passes and what they closed}

## Lenses (pashov solidity-auditor, slimmed). Walk every in-scope function through each.
1. Access: every external function's caller check; every callback accepted only from the venue the contract is calling
   now, once; self-call entry points; who can make the contract call an arbitrary target with arbitrary data.
2. Boundaries, at each external call: no code at the target; a token that returns nothing, returns false, takes a fee,
   rebases, blocks or pauses; zero, max and empty inputs; a return value or revert data the caller trusts (a venue
   raising the contract's own custom error); a proxy whose implementation can change.
3. Execution trace: claimed amount against amount actually moved; packed or assembly decoding read at the wrong
   offset or width; a sentinel value that skips a check; a value read, then an external call, then the stale value used;
   a setter fired while an operation is in flight; an allowance left above what was consumed.
4. Flow gaps: balance-before/after deltas across a call that hands control out; re-entry into any entry point from a
   callback or hook mid-flow; two steps each correct whose combined end state is wrong.
5. Invariants: write each one (what is held = what should be held; nothing left behind; profit is a delta, never a
   balance); find every path that changes a term and the one that skips the check; simulate/quote paths whose result
   differs from the executing path.
6. Asymmetry: paired operations (approve and revoke, borrow and repay, simulate and execute, path A and path B of one
   function): diff their validation and their writes; a branch that skips a check the other runs.
7. Math: unsafe narrowing casts, signed/unsigned mixes, rounding direction, overflow before a check, scale mismatch.
8. Trust: what each standing approval, admin setter and trusted external contract can do to what the contract holds,
   and what an unprivileged actor gains if one of them misbehaves.

## Judging (pashov's gates; apply before you report)
A FINDING needs a proof: concrete values, a trace, or quoted code, from the attacker's call to the harm. Gate 1: no guard
on the path stops it (quote the line if one does). Gate 2: the state is reachable live. Gate 3: an unprivileged actor
triggers it (admin-only harm is rejected unless an unprivileged amplifier is named). Gate 4: material harm to someone
other than the caller. A finding that fails a gate but leaves a real smell is a LEAD. Do not report gas, naming,
events, centralization without a mechanism, or admin doing admin things.

## Constraints
At most 700 words. Read narrowly (rg -n, sed ranges). Do not edit any file in the repo; write a proof of concept under
{root}/tmp/solidity-review/poc/ and quote it.

## Output
For each item:
    [FINDING | LEAD] [CRITICAL | HIGH | MEDIUM | LOW] title
    lens: N; function: name
    path: caller -> call -> state change -> harm
    proof: values, trace or quoted code (FINDING only)
    fix: one sentence
    Location: path:line
End with: VERDICT: Deploy | VERDICT: Do not deploy until FINDINGs are fixed
```

## Run

Same as /impl-review: `<root>` from `git rev-parse --show-toplevel`, `<stamp>` from `date +%Y%m%d-%H%M%S` plus `-<topic>`, prompt over stdin with a quoted heredoc, background, output kept in the project's tmp.

```bash
mkdir -p <root>/tmp/solidity-review
codex exec --json -C <root> -m <model> -c model_reasoning_effort=xhigh -o <root>/tmp/solidity-review/<stamp>.md - > <root>/tmp/solidity-review/<stamp>.jsonl <<'PROMPT'
{the prompt}
PROMPT
```

`<model>` is the newest Astra, resolved the way /impl-review does it (`~/.codex/models_cache.json`, lowest `priority`) and written literally; empty output means stop and tell the user rather than guess a slug.

Rebuttal rounds as /impl-review describes (`codex exec resume <thread_id>`, read-only sandbox, at most two, `HOLD` or `CONCEDE` per disputed item; after a fix, `CLOSED` or `OPEN` per finding).

## Reporting

Read the `-o` file. Print the VERDICT, then FINDINGs by severity, then LEADs. Judge each one yourself before any change: how the input occurs live, what it costs when it does, and the code its fix adds (a project's own rule on judging findings applies). A FINDING you agree with is fixed and its class searched for in the rest of the contract, then sent back for `CLOSED`; a LEAD is recorded or chased by its cost. A finding that changes the design goes to the user with both positions. Log one line when settled:

```bash
jq -nc '{date: (now | todate), project: "<repo>", skill: "solidity-review", reviewer: "codex", model: "<model>", findings: {finding: 0, lead: 0}, accepted: 0, rejected: 0, user_overrode: 0, rounds: 1, conceded: 0, seconds: 0}' >> ~/.local/state/review/log.jsonl
```
