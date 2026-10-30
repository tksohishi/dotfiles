---
name: tmp-plan
description: Write a short problem brief into a project's tmp/plans/ (updating a relevant existing brief instead when one exists, and trashing relevant ones already done) holding the goal, the problems, what was measured or considered about each (or the doc that already has it) and a one-line direction per problem, with no implementation detail and no code references. Use when the user runs /tmp-plan [project] [topic], or asks to write up the session's findings as a plan/brief doc in tmp/.
---

# tmp-plan

Writes `<project>/tmp/plans/<YYYY-MM-DD>-<slug>.md`. The document is the input to a later decision or implementation session, often in a fresh context, so it has to stand on its own: whoever reads it was not in this conversation. Its frontmatter is what `/prioritize` ranks it by.

The weight is on what is known, not what to build. Solutions get the least space: a session's proposed fix is the part most likely to be wrong and the easiest to redo, while a measurement, a ruled-out path or a user decision is expensive to rediscover. The brief is short: problems, the evidence on each, a direction. Implementation detail and code references are not in it (see Content).

## Where it goes

- No project argument: `tmp/plans/` under the current working directory's project root (`git rev-parse --show-toplevel`, else cwd).
- Project argument: an absolute or relative path, or a bare name resolved under `~/work/<name>`. If it doesn't resolve to an existing directory, ask rather than guess.
- Create `tmp/plans/` if missing (`tmp/` is globally gitignored). Filename: `date +%F` plus a short kebab-case slug of the topic. If that file exists, pick a different slug; never overwrite.

## Find existing briefs first

A new brief is the last resort. Two briefs on one topic split the facts and leave `/prioritize` ranking the same work twice.

1. Read only the frontmatter of every brief in `tmp/plans/` (`goal`, `touches`, `todo`, `blocked`), not the bodies.
2. A brief is relevant when its `goal` covers the same problem or its `touches` overlap the paths this session's work would change.
3. Relevant and still open or blocked: update that brief in place instead of writing a new one. Merge this session's facts, results and decisions into its sections, rewrite `todo` and `blocked` to match what is still to do, add what this session shipped to `done`, and keep its filename. Read its body now, since you are editing it.
4. Relevant but done (`todo` and `blocked` both empty, or every item in them covered by commits on its `touches` since its date, per `git log`): trash it (`trash`, not `rm`). If its body holds a measurement or ruled-out path nothing else records, carry it into the brief being written first.
5. Write a new brief only when no relevant open brief exists, or when this session's topic is a separate goal that would make an existing brief about two things.

Leave unrelated briefs alone; sweeping the whole directory is `/prioritize`'s job.

## Ground it first

Write from evidence, not recollection:

- Review the whole session: what was asked, what was measured or read, what was tried and dropped, what the user decided. Decisions made in conversation exist nowhere else.
- Re-open the sources a fact rests on (output files under `tmp/`, code paths, docs, URLs already fetched) where they are still at hand, and copy numbers from them rather than from memory.
- If the transcript and a re-check disagree, the re-check wins; note the discrepancy if it matters.

## Frontmatter

The file opens with a YAML block that holds its state. A later `/prioritize` run reads this block and `git log` on the paths it names and nothing else, so everything that decides whether the brief is done, open or blocked, and where it ranks, has to be here, not only in the body.

```yaml
---
goal: "<one line: what the brief is for and why it matters to the project's goal>"
touches: [scripts/foo/main.ts, lib/bar.ts]   # the code paths the open work would change; git log on these is the shipped check
done: []                # "<hash> <what it covered>", filled in as work lands
todo:
  - "1. [P0] <one line per item startable now, concrete enough to start from>"
  - "2. [P2] <...>"
blocked:
  - "<item text> — trigger: <one line: the measurement, event or user decision that unblocks it>"
---
```

There is no `status` key; the state is derived. Empty `todo` and empty `blocked`: done. Empty `todo` with items in `blocked`: blocked. Otherwise open.

Rules:
- `touches` names real paths at the granularity of the work (a file when one file changes, a directory when the work spans it). A brief about a decision with no code yet names the paths the decision would land in. Verify each path exists (`ls`).
- `todo` is the list a fresh session could start from: one item per line, an action with its object, not a question. Questions go in the body's Open questions. Each line is `"<n>. [P<0|1|2>] <text>"`, ordered P0, P1, P2 and numbered 1, 2, 3... in that order. P0 and P1 come only from the user's ranking; any other item is P2. When the list changes, renumber it and rewrite every reference to a changed number (`todo N`) in the brief's lines, note and body and in other briefs that point at it.
- `blocked` holds the items that wait on a measurement still to accrue, an outside event or a user decision, each followed by ` — trigger: ` and what unblocks it. An item goes there only when no part of it can start now; when its trigger fires it moves to `todo` with a priority.
- `goal` is written against the project's stated goal (its AGENTS.md or CLAUDE.md), so the ranking does not have to re-derive the link.
- Strings are double-quoted YAML. A new brief's `done` is empty; it is filled by the session that ships the work or by `/prioritize`.

## Content

Write in the language the session was conducted in. Times in the user's local zone (e.g. `10/12 13:30 EDT`). Title states the question or topic, with the date.

The brief is a problem statement with its evidence, not a design. It holds three things: the problems, what was measured or considered about each (or a pointer to the doc that already holds it), and a one-line direction per problem. The implementation (which function, which file, which line, how the change is built, what the tests cover) is left out entirely: it is the implementing session's to work out from the code, and it is the part most often wrong by the time the brief is picked up. Code is referenced only by behaviour ("the plan refuses a trip whose worst loss passes the cap"), never by path or line; the `touches` list in the frontmatter is the one place a code path appears.

Length: a brief is read before a decision, so it fits on one screen or two, about 40 lines of body and under 600 words. When the material is larger, the measurements go to a file under `tmp/<topic>/` or a `docs/` page and the brief carries the figures that decide and a pointer. A fact already in `docs/` is a one-line reference to that doc, not a restatement.

Sections, in this order, dropping any that would be empty:

1. **Goal**: what the user is trying to achieve and why, in their terms. One to three lines.
2. **Problems**: the concrete problems standing between now and the goal, each one or two lines stating the observable symptom and its impact (what breaks, how often, what it costs), not a fix. Numbered so later sections refer to them.
3. **What was measured and considered**: per problem, the measurements (method in a clause, the deciding figures, the raw file) and the paths considered and dropped with the evidence that dropped them, each a line or two. A fact that lives in a doc is its reference. Time-sensitive readings carry when they were observed.
4. **Decisions and constraints**: what the user decided or required, as plain facts. One line each.
5. **Open questions**: what is still unknown, with what would settle it and the problem it bears on. One line each.
6. **Direction**: one or two lines per problem on the way forward, unranked unless the user ranked them, tagged with the problem number. No mechanism, no code.
7. **References**: the docs, raw files, URLs and commits the reader should open. Not code paths.

Label anything not verified this session as unverified and name what would settle it; don't present inference as fact.

Before writing, cut: any sentence that explains how the code works today, any sentence that describes how a fix would be built, any file:line, any number that does not change a decision, and any restatement of something a doc already says.

No em dashes.

## After writing

Reply with the path in backticks, whether it was created or updated, a one-line summary of what it covers, and any brief trashed with the reason in a few words. Don't paste the document into the chat.
