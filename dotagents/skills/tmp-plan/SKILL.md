---
name: tmp-plan
description: Write a PRD-style markdown brief into a project's tmp/ capturing the goal, problems to solve, and what this session researched and discussed, weighted toward verified facts and research results rather than solutions. Use when the user runs /tmp-plan [project] [topic], or asks to write up the session's findings as a plan/brief doc in tmp/.
disable-model-invocation: true
---

# tmp-plan

Writes `<project>/tmp/<YYYY-MM-DD>-<slug>.md`. The document is the input to a later decision or implementation session, often in a fresh context, so it has to stand on its own: whoever reads it was not in this conversation.

The weight is on what is known, not what to build. Solutions get the least space: a session's proposed fix is the part most likely to be wrong and the easiest to redo, while a measurement, a ruled-out path or a user decision is expensive to rediscover.

## Where it goes

- No project argument: `tmp/` under the current working directory's project root (`git rev-parse --show-toplevel`, else cwd).
- Project argument: an absolute or relative path, or a bare name resolved under `~/work/<name>`. If it doesn't resolve to an existing directory, ask rather than guess.
- Create `tmp/` if missing (it is globally gitignored). Filename: `date +%F` plus a short kebab-case slug of the topic. If that file exists, pick a different slug; never overwrite.

## Ground it first

Write from evidence, not recollection:

- Review the whole session: what was asked, what was measured or read, what was tried and dropped, what the user decided. Decisions made in conversation exist nowhere else.
- Re-open the sources a fact rests on (output files under `tmp/`, code paths, docs, URLs already fetched) where they are still at hand, and copy numbers from them rather than from memory.
- If the transcript and a re-check disagree, the re-check wins; note the discrepancy if it matters.

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

Load the `humanizer` skill before drafting and apply it. No em dashes.

## After writing

Reply with the clickable path (`[name](file:///abs/path)`) and a one-line summary of what it covers. Don't paste the document into the chat.
