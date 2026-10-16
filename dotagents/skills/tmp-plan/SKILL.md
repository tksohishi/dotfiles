---
name: tmp-plan
description: Write a PRD-style markdown brief into a project's tmp/plans/ (updating a relevant existing brief instead when one exists, and trashing relevant ones already done) capturing the goal, problems to solve, and what this session researched and discussed, weighted toward verified facts and research results rather than solutions. Use when the user runs /tmp-plan [project] [topic], or asks to write up the session's findings as a plan/brief doc in tmp/.
model: opus
---

# tmp-plan

Writes `<project>/tmp/plans/<YYYY-MM-DD>-<slug>.md`. The document is the input to a later decision or implementation session, often in a fresh context, so it has to stand on its own: whoever reads it was not in this conversation. Its frontmatter is what `/prioritize` ranks it by.

The weight is on what is known, not what to build. Solutions get the least space: a session's proposed fix is the part most likely to be wrong and the easiest to redo, while a measurement, a ruled-out path or a user decision is expensive to rediscover.

## Where it goes

- No project argument: `tmp/plans/` under the current working directory's project root (`git rev-parse --show-toplevel`, else cwd).
- Project argument: an absolute or relative path, or a bare name resolved under `~/work/<name>`. If it doesn't resolve to an existing directory, ask rather than guess.
- Create `tmp/plans/` if missing (`tmp/` is globally gitignored). Filename: `date +%F` plus a short kebab-case slug of the topic. If that file exists, pick a different slug; never overwrite.

## Find existing briefs first

A new brief is the last resort. Two briefs on one topic split the facts and leave `/prioritize` ranking the same work twice.

1. Read only the frontmatter of every brief in `tmp/plans/` (`goal`, `status`, `touches`, `open`), not the bodies.
2. A brief is relevant when its `goal` covers the same problem or its `touches` overlap the paths this session's work would change.
3. Relevant and still open: update that brief in place instead of writing a new one. Merge this session's facts, results and decisions into its sections, rewrite `open` to match what is still to do, and keep its filename. Read its body now, since you are editing it.
4. Relevant but done (`status: done`, or every `open` item covered by commits on its `touches` since its date, per `git log`): trash it (`trash`, not `rm`). If its body holds a measurement or ruled-out path nothing else records, carry it into the brief being written first.
5. Write a new brief only when no relevant open brief exists, or when this session's topic is a separate goal that would make an existing brief about two things.

Leave unrelated briefs alone; sweeping the whole directory is `/prioritize`'s job.

## Ground it first

Write from evidence, not recollection:

- Review the whole session: what was asked, what was measured or read, what was tried and dropped, what the user decided. Decisions made in conversation exist nowhere else.
- Re-open the sources a fact rests on (output files under `tmp/`, code paths, docs, URLs already fetched) where they are still at hand, and copy numbers from them rather than from memory.
- If the transcript and a re-check disagree, the re-check wins; note the discrepancy if it matters.

## Frontmatter

The file opens with a YAML block that holds its state. A later `/prioritize` run reads this block and `git log` on the paths it names and nothing else, so everything that decides whether the brief is done, half done, open or waiting, and where it ranks, has to be here, not only in the body.

```yaml
---
status: open            # open | partial | waiting | done
goal: <one line: what the brief is for and why it matters to the project's goal>
touches: [scripts/foo/main.ts, lib/bar.ts]   # the code paths the open work would change; git log on these is the shipped check
open:
  - <one line per item still to do, concrete enough to start from; numbered like the body's problems>
waiting: <only with status waiting: the event, date or user decision it waits on>
shipped: []             # <hash> <what it covered>, filled in as work lands
---
```

Rules:
- `touches` names real paths at the granularity of the work (a file when one file changes, a directory when the work spans it). A brief about a decision with no code yet names the paths the decision would land in. Verify each path exists (`ls`).
- `open` is the list a fresh session could start from: one item per line, an action with its object, not a question. Questions go in the body's Open questions. A brief with nothing startable is `waiting`, with the trigger named.
- `goal` is written against the project's stated goal (its AGENTS.md or CLAUDE.md), so the ranking does not have to re-derive the link.
- A new brief is never `done` or `partial`; those are set by `/prioritize` or by the session that ships the work.

## Content

Write in the language the session was conducted in. Times in the user's local zone (e.g. `10/12 13:30 EDT`). Title states the question or topic, with the date.

Sections, in this order, dropping any that would be empty:

1. **Goal**: what the user is trying to achieve and why, in their terms. Two to four lines.
2. **Problems to solve**: the concrete problems standing between now and the goal, each stated as an observable symptom or gap with its impact (what breaks, how often, what it costs), not as a fix. Numbered so later sections and sessions can refer to them.
3. **Facts**: verified findings, each with its source (file:line, command, URL, measurement file) and, for anything time-sensitive, when it was observed. Exact identifiers, numbers and units; no rounding that loses meaning.
4. **Research results**: measurements and experiments, each with method (where it ran, sample size, conditions), result (min/p50/p90 or the raw counts) and the file holding the raw output. A one-line reading of what the numbers imply may follow each.
5. **Ruled out**: paths considered and dropped, each with the evidence that ruled it out, so nobody retries them.
6. **Decisions and constraints**: what the user decided or required during the session, stated as plain facts.
7. **Open questions**: what is still unknown, each with what would settle it and which problem it bears on.
8. **Options** (brief): directions mentioned, unranked unless the user ranked them, one or two lines each, tagged with the problem number they address. No implementation detail.
9. **References**: files, scripts, URLs, commits the reader should open.

Label anything not verified this session as unverified and name what would settle it; don't present inference as fact.

No em dashes.

## After writing

Reply with the clickable path (`[name](file:///abs/path)`), whether it was created or updated, a one-line summary of what it covers, and any brief trashed with the reason in a few words. Don't paste the document into the chat.
