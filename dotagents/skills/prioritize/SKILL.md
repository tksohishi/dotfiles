---
name: prioritize
description: Rank the plan documents under a project's tmp/ (the tmp-plan briefs) against what has shipped since and the project's stated goal, clean up the ones that are done or half done, and present the user one ranked list of what to decide or start next. Use when the user runs /prioritize [project], asks 次何やる / 優先順位をつけて / tmp の plan を整理して, or asks which of the pending plans to pick up.
---

# prioritize

Reads `tmp/<YYYY-MM-DD>-<slug>.md` (the briefs `tmp-plan` writes), decides for each whether it is done, half done, open or waiting, cleans up accordingly, and ranks what is left. The output is a decision aid for the user, not a plan of record: nothing is started.

The cost driver is reading. A brief carries its state in a frontmatter block (the schema is in `tmp-plan`), so the main session reads frontmatter and git subjects only; a brief without one is retrofitted by a subagent once and then costs the same as the rest.

## Where it runs

- No argument: the current project root (`git rev-parse --show-toplevel`, else cwd). Argument: a path, or a bare name under `~/work/<name>`. If it does not resolve, ask.
- Scope is `tmp/[0-9][0-9][0-9][0-9]-*.md`. Other files under `tmp/` (scripts, outputs, traces, handoffs) are not plans; they are read only when a frontmatter names one as evidence.

## 1. The goal

Read the project's goal once, from the overview or goal section of its instruction file (`AGENTS.md` or `CLAUDE.md`) and from what the user said this session. Rank against that, not against what sounds interesting. If the instruction file has no goal statement, say so and rank on risk and cost alone.

## 2. Read the state, cheaply

For every brief in scope:

```
sed -n '1{/^---$/!q;};2,/^---$/p' tmp/<file>.md     # the frontmatter alone; prints nothing when line 1 is not a fence
```

- Empty output means no frontmatter: put it on the retrofit list.
- A frontmatter with `status: done` is a leftover from a run that did not finish: trash it now.
- For the rest, check what shipped on its paths since its date (the date is the filename prefix): `git log --oneline --since=<date> -- <touches>`, subjects only. Zero commits on the touched paths and `status: open` means still open; no further reading. Any commit means the `open` items may have moved: put the brief on the recheck list.

Never read a brief's body in the main session. The body is facts and measurements for whoever implements it; the frontmatter is the state, and if the state is wrong the fix is a retrofit, not a read.

## 3. Retrofit and recheck, delegated

Hand the retrofit and recheck lists to subagents, about eight briefs each, all launched in one message. Each agent gets:

- the list of briefs and today's date;
- read-only rules: `cat`, `sed`, `rg`, `fd`, `git log`, `git show`; no edits, no commits, no scripts that touch a network;
- the job per brief: read it whole, find what shipped (`git log --oneline --since=<date> -- <paths it names>`, plus a subject search on its keywords, plus the current code at the symbols it names), and write one file per brief into the session scratchpad holding the frontmatter fields (`status`, `goal`, `touches`, `shipped`, `open`, `waiting`) plus an `evidence:` line with the file:line or hash behind the status;
- a reply under 200 words: one line per brief and anything it was unsure about.

Integrate from the files, not the replies. Spot-check before applying: every hash an agent calls shipped exists (`git cat-file -e <hash>^{commit}`; a hash from another repo, such as dotfiles, is checked there) and its subject matches the claim; a `done` verdict gets one `rg` on the doc's main symbol. An agent that could not decide leaves the brief `open` with a note; a wrong `done` loses a brief, a wrong `open` costs one more read next time.

## 4. Clean up

- `done`: `trash tmp/<file>.md`. The findings live in the commits it named; if a body holds a measurement nothing else records (a probe result, a ruled-out path with its evidence), move that paragraph to the project's docs or a memory first, then trash.
- `partial`, `open`, `waiting`: write the frontmatter (replace the old block or insert one above the title) with the new `status`, `shipped` and `open` lists. The body stays; it is history and evidence. Edit a body line only where it now contradicts the frontmatter in a way that would mislead the implementer (an item the body still proposes that a commit ruled out).
- A brief whose `open` items are all covered by another brief is folded: its unique facts move into the other, and it is trashed. An item that two briefs both list is kept in one and the other points at it.
- A handoff left in `tmp/` by a previous session (the kind the `handoff` skill writes) is not a plan: its open items become a brief if they would otherwise be lost, then it is trashed.

One tool call per file. `tmp/` is gitignored, so there is nothing to commit; say so if the user asks.

## 5. Rank

Two axes and one attribute. Whether the work can start now is not an axis: it only says who acts, the user with a minute of judgment or a session with hours of work. A decision the user owes is ranked on the same scale as a change a session would make, and the user answers at once by default; when they cannot, they say so, the brief goes `waiting` with the trigger named, and it leaves the ranking until the trigger fires.

**Importance** (what the result moves), four tiers:
- S: an irreversible loss at stake (money on a path that sends, data, an account), a loss not bounded, a guard missing.
- A: moves the goal's own number in a measurable way (in a trading project: a miss that becomes a take, a race lost today that is won, a market not yet covered).
- B: stops a recurring incident or cost (a false alert, a resident that goes quiet, a budget hole, a restart that loses state).
- C: hygiene, research with no decision riding on it, work outside the goal.

**Urgency** (what delay loses), three levels:
- Deadline: a date or event past which the result has no value. The deadline is the last day the answer still leaves time for the work it enables, not the event itself: an event on day E whose work needs N days is due on E minus N (a reveal on Monday with a mandate, a dry run and a box to set up is a decision due the Friday before). Compute dates with `date`, name the weekday, and write what the lead time is for.
- Bleed: each day of delay costs money or openings (a race lost the same way daily, a coverage hole rivals take from).
- None.

**A decision inherits the importance of the best item it unblocks**, and the deadline of that item. A decision whose likely answer is "no" still ranks on what it unblocks: a "no" trashes a brief and clears the list, which is worth the user's minute.

Order: importance first; within a tier, urgency (deadline, then bleed, then none); within that, the cheaper first, which puts a pending decision ahead of a change in the same tier. A deadline within a week lifts the item one tier. No numeric scores: an ordinal tier is the honest precision.

Cost is the attribute: for a decision, what the user has to read first; for a change, the size and the review bar the project's instruction file sets (a buy path or a production path needs its review and rehearsal steps; a doc or script change needs a test).

## 6. Present

Write in the language the user is using. One list, one row per brief, one screen:

- rank; brief (clickable `[name](file:///abs/path)`); who (the user, or a session); the first step in one line: the question to answer when a decision is pending, else the first item to do; tier and urgency (the deadline with its weekday and what the lead time is for, or bleed); cost.
- A brief with several open items ranks on its best item; the rest ride along and are not listed.
- Below the list: what the cleanup did (trashed with why in a few words, rewritten with the new status, folded) and anything a spot-check contradicted, with the agent's claim and the evidence. Briefs already `waiting` on a trigger that has not fired are listed in one line each, trigger included, after the ranking.

Then stop. Ask nothing; the user picks. Do not start the top item, do not commit, do not write a handoff.
