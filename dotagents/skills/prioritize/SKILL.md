---
name: prioritize
description: Rank the plan documents under a project's tmp/plans/ (the tmp-plan briefs) against what has shipped since and the project's stated goal, clean up the ones that are done or half done, and present the user one ranked list of what to decide or start next. Use when the user runs /prioritize [project], asks 次何やる / 優先順位をつけて / tmp の plan を整理して, or asks which of the pending plans to pick up.
---

# prioritize

Reads `tmp/plans/<YYYY-MM-DD>-<slug>.md` (the briefs `tmp-plan` writes), decides for each whether it is done, open or blocked, cleans up accordingly, and ranks what is left. The output puts in front of the user only what is theirs to decide, and hands the rest to sessions they start with a click: nothing starts without that click.

The cost driver is reading. A brief carries its state in a frontmatter block (the schema is in `tmp-plan`), so the main session reads frontmatter and git subjects only; a brief without one is retrofitted by a subagent once and then costs the same as the rest.

## Where it runs

- No argument: the current project root (`git rev-parse --show-toplevel`, else cwd). Argument: a path, or a bare name under `~/work/<name>`. If it does not resolve, ask.
- Scope is `tmp/plans/*.md`. Other files under `tmp/` (scripts, outputs, traces, handoffs) are not plans; they are read only when a frontmatter names one as evidence.

## 1. The goal

Read the project's goal once, from the overview or goal section of its instruction file (`AGENTS.md` or `CLAUDE.md`) and from what the user said this session. Rank against that, not against what sounds interesting. If the instruction file has no goal statement, say so and rank on risk and cost alone.

## 2. Read the state, cheaply

Run `~/.agents/skills/prioritize/scripts/state.sh [project-root]` once. It prints each brief's frontmatter and the number of commits on its `touches` paths since the brief's date, and never a body.

- `no-frontmatter`, or an old schema (a `status`, `shipped`, `open` or `waiting` key): put it on the retrofit list.
- Empty `todo` and empty `blocked` is a done brief left by a run that did not finish: trash it now.
- `commits-since: 0` means `todo` stands; no further reading. Any commit means the `todo` items may have moved: put the brief on the recheck list. `n/a` (no `touches`) goes to the retrofit list.
- A `blocked` line whose trigger names a date that has passed, or a count the session can see has accrued, goes on the recheck list too; a trigger that waits on the user is asked about in the presentation, not rechecked.

Never read a brief's body in the main session. The body is facts and measurements for whoever implements it; the frontmatter is the state, and if the state is wrong the fix is a retrofit, not a read.

## 3. Retrofit and recheck, delegated

Hand the retrofit and recheck lists to subagents, about eight briefs each, all launched in one message. Each agent gets:

- the list of briefs and today's date;
- read-only rules: `cat`, `sed`, `rg`, `fd`, `git log`, `git show`; no edits, no commits, no scripts that touch a network;
- the job per brief: read it whole, find what shipped (commits since its date on the paths it names, a subject search on its keywords, and the current code at the symbols it names), and write one file per brief into the session scratchpad holding the frontmatter fields (`goal`, `touches`, `done`, `todo`, `blocked`, in the schema `tmp-plan` gives, keeping each `todo` line's priority tag) plus an `evidence:` line with the file:line or hash behind each item moved to `done` or out of `blocked`;
- for each `todo` item, its latest dated note: whether what it waits on still holds (a deploy: compare the commit with the host's deployed-commit record where the project keeps one, e.g. `git merge-base --is-ancestor <hash> <deployed>`; a measurement or trigger: whether it has accrued, from sources it can read without a network); a next step that no longer holds is rewritten, and the evidence line says so;
- a reply under 200 words: one line per brief and anything it was unsure about.

Integrate from the files, not the replies. Spot-check before applying: every hash an agent calls shipped exists (in its own repo, which may not be this one) and its subject matches the claim; a `done` verdict gets one search for the doc's main symbol. An agent that could not decide leaves the item in `todo` with a note; a wrong `done` loses work, a wrong `todo` costs one more read next time.

## 4. Clean up

- Done (empty `todo` and `blocked`): trash it (`trash`, not `rm`). The findings live in the commits it named; if a body holds a measurement nothing else records (a probe result, a ruled-out path with its evidence), move that paragraph to the project's docs or a memory first, then trash.
- Open or blocked: write the frontmatter (replace the old block or insert one above the title) with the new `done`, `todo` and `blocked` lists. Shipped items move to `done`; a `blocked` item whose trigger fired moves to `todo` as P2 unless the user ranked it; `todo` stays in priority order (P0, then P1, then P2) with no numbers; a line still carrying an `<n>. ` prefix loses it. Every `todo` and `blocked` item carries a `{slug}` as `tmp-plan` says: one that lacks it gets one, and a duplicate in the brief is renamed. A `todo N` reference (the brief's own lines, note and body, and other briefs that point at it by file name) is rewritten to the slug of the item it meant, read before the prefix is dropped; a `旧 todo N` (an earlier number kept as history) and a reference into another brief's own numbering stay as written. A `{slug}` that names no item any more is pointed at the `done` line that holds it, or reported below the list when none does. The body stays; it is history and evidence. Edit a body line only where it now contradicts the frontmatter in a way that would mislead the implementer (an item the body still proposes that a commit ruled out, a `todo N` that no longer names an item).
- A brief whose `todo` and `blocked` items are all covered by another brief is folded: its unique facts move into the other, and it is trashed. An item that two briefs both list is kept in one and the other points at it.
- Flag items that describe the same change in two briefs (same change, even under different slugs): the owner is the brief that owns what the item changes, and the other keeps only a pointer `{id}（<brief file>）`. Report each one below the list; move it only on the user's word.
- A handoff left in `tmp/` by a previous session (the kind the `handoff` skill writes) is not a plan: its open items become a brief if they would otherwise be lost, then it is trashed.

One tool call per file. `tmp/` is gitignored, so there is nothing to commit; say so if the user asks.

## 5. Rank

Two axes and one attribute. Whether the work can start now is not an axis: it only says who acts, the user with a minute of judgment or a session with hours of work. A decision the user owes is ranked on the same scale as a change a session would make, and the user answers at once by default; when they cannot, they say so, the item goes to `blocked` with the trigger named, and it leaves the ranking until the trigger fires.

The user's tags come first: P0 items rank above everything, then P1, then P2. The tiers below order items within a tag, and only P2 is ranked by them alone. A tag changes only on the user's word.

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

## 5b. Review the verdicts and the ranking

Before presenting, a second model reads the subagents' work and the draft ranking cold. Write the draft ranking (both lists, one row per brief with its tier, urgency, cost and first step) to `<root>/tmp/prioritize/<stamp>-ranking.md`, then run Claude Fable at xhigh, read-only, in the background, as `arch-review` does:

```bash
claude -p --session-id <uuid> --add-dir <root> --model fable --effort xhigh --permission-mode dontAsk --disallowedTools "Edit Write NotebookEdit" > <root>/tmp/prioritize/<stamp>-review.md <<'PROMPT'
{the prompt}
PROMPT
```

The prompt (under ~2KB) gives the goal quoted from the instruction file and the user's words this session, the paths of the agents' output files and of the draft ranking, the briefs they cover, and the user's P tags as decided. It asks:

- Verdicts: for each item an agent moved to `done` or out of `blocked`, does its evidence hold (the hash exists, its subject and diff do what the item asked, it is in the deployed commit when the item waited on a deploy)? Which `todo` items look already done or obsolete?
- Ranking: against the goal, which rows are in the wrong tier or urgency, which duplicates or overlaps were missed, what is missing that the briefs show, and what the top three should be and why.
- Output under 600 words: findings tagged `[VERDICT]` or `[RANK]`, each with the brief, the claim, the evidence (file:line or hash) and the change proposed.

Judge each finding as `impl-review` does: check its evidence before taking it, apply what holds to the frontmatter and the draft, and say why for one you reject. A finding that would change a user's P tag is not applied: it goes to the user in the presentation. Log one line to `~/.local/state/review/log.jsonl` with `skill: "prioritize"`, `reviewer: "claude"`, `model: "fable"` and the counts.

## 6. Present

Write in the language the user is using. Two ranked lists on one screen, one row per brief: "Your decisions" (rows whose next step is the user's: a question, a go, an account or a key) first, then "For sessions" (rows a session can do now). Each row:

- rank; brief (its name, no link); the first step in one line: the question to answer when a decision is pending, else the first `todo` item (its slug and tag) at its latest next step, read from its last dated note and not its opening text, which is the plan as first written; when that note waits on the user, the row goes to "Your decisions"; tier and urgency (the deadline with its weekday and what the lead time is for, or bleed); cost.
- An item is in progress when a commit named in the item, or a commit on its `touches` whose subject matches its slug keywords, is within the last 48 hours. An in-progress item whose latest next step leaves no code to write now (it waits on a measurement, a race, a deploy's read or the user) leaves the ranking for an "In progress" section above it, one line each with what it waits on; one with code still to write stays ranked, marked in progress.
- A brief with several `todo` items ranks on its best item; the rest ride along and are not listed, except that a P1 or P2 item of a brief that also holds P0 items gets its own row when it outranks the briefs whose best item has its tag.
- Below the list: the reviewer's findings, one line each with taken or rejected and why (a P-tag change it proposed is asked here); then what the cleanup did (trashed with why in a few words, items moved to `done` or out of `blocked`, folded) and anything a spot-check contradicted, with the agent's claim and the evidence. Blocked briefs (empty `todo`) whose triggers have not fired are listed in one line each, trigger included, after the ranking. An item with no step anyone can take now is `blocked` with its trigger, never a ranked row marked on hold.
- "For sessions" is grouped into lanes: rows whose `touches` share a file go in one lane, in rank order, since two sessions writing the same file overwrite each other.

Then propose the first row of each of the top lanes as a session card (`start_session`, initiation `own_initiative`, context `fresh`), three at most: the brief names the brief file, the item's slug, its latest next step, and done as the project's instruction file defines it for that kind of change (its reviews, tests, dry run, and the deploy go left to the user). Ask nothing else; the user decides the rows in "Your decisions" and starts the cards. Do not start an item yourself, do not commit, do not write a handoff.
