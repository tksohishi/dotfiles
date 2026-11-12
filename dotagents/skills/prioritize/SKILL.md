---
name: prioritize
description: Rank a project's tmp/backlog.md (the lines /later writes) against the project's goal and what has shipped since, offer stale lines for deletion, and present one ranked list of what to decide or start next. Use when the user runs /prioritize [project], asks 次何やる / 優先順位をつけて / backlog を整理して, or asks which pending item to pick up.
---

# prioritize

Reads `tmp/backlog.md` (format in the `later` skill) in one pass and ranks it. Nothing starts without the user: the output is a list and at most three session cards.

## Where it runs

No argument: the current project root (`git rev-parse --show-toplevel`, else cwd). Argument: a path, or a bare name under `~/work/<name>`. If it does not resolve, ask. No `tmp/backlog.md`: say so and stop.

## 1. Read

- The project's goal, from the overview or goal section of `AGENTS.md` or `CLAUDE.md`, and what the user said this session. Rank against that. No goal statement: say so and rank on risk and cost alone.
- The whole backlog.
- Per line, one shipped check: `git log --oneline --since=<its date> -i --grep=<topic words>` and, where the slug names a path, `git log` on it. A commit that plainly does the line's work makes it a deletion candidate, with the hash as evidence.
- A `when:` trigger that names a date or a count the session can check: whether it has fired.

Do not open `see:` paths or read code to rank. A line too vague to rank is reported as such.

## 2. Clean up (on the user's word)

Collect, below the ranking, one batch the user approves or edits:
- lines a commit already covers (hash and subject);
- lines older than about 45 days whose `when:` has not fired, or with no `when:` that nobody started;
- lines that say the same thing (keep the clearer one).

Delete approved lines with Edit, one line per edit. A fired trigger is dropped from its line (`when:` removed) so the line becomes startable.

## 3. Rank

`!` lines rank above the rest; the rubric below orders within each group.

**Importance** (what the result moves):
- S: an irreversible loss at stake (money on a path that sends, data, an account), a loss not bounded, a guard missing.
- A: moves the goal's own number measurably.
- B: stops a recurring incident or cost.
- C: hygiene, research with no decision riding on it, work outside the goal.

**Urgency** (what delay loses): a deadline (the last day the answer still leaves time for the work it enables; compute with `date` and name the weekday), bleed (each day of delay costs money or openings), or none.

Order: importance, then urgency (deadline, bleed, none), then the cheaper first. A deadline within a week lifts the item one tier. A decision the user owes inherits the importance and deadline of what it unblocks. No numeric scores.

## 4. Present

In the user's language, on one screen:

1. "Your decisions": lines whose next step is the user's (a question, a go, an account or a key), ranked.
2. "For sessions": startable lines, ranked, grouped by scope so one app's session takes its own lane.
3. Waiting: lines with an unfired `when:`, one line each with the trigger.
4. The cleanup batch from step 2.

Each row: rank, slug, the line's what, tier and urgency, cost in a few words.

Then offer the top line of up to three scopes as session cards (`start_session`, initiation `own_initiative`, context `fresh`) naming the slug and the line. Do not start an item yourself and do not commit.
