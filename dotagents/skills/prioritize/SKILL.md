---
name: prioritize
description: Rank a project's backlog (tmp/backlog/<scope>.md, the lines /later writes) against the project's goal and what has shipped since, propose P0/P1 changes, offer stale lines for deletion, and present one ranked list of what to decide or start next. Use when the user runs /prioritize [scope] [project], asks 次何やる / 優先順位をつけて / backlog を整理して, or asks which pending item to pick up.
---

# prioritize

Reads the backlog (format in the `later` skill) in one pass and ranks it. Nothing starts without the user: the output is a list and at most three session cards.

## Where it runs

- Project: the current project root (`git rev-parse --show-toplevel`, else cwd), or a path or bare name under `~/work/<name>` given as an argument. If it does not resolve, ask.
- Scope: an argument naming a file in `tmp/backlog/` ranks that file alone; without one, all files are ranked together. No backlog: say so and stop.

## 1. Read

- The project's goal, from the overview or goal section of `AGENTS.md` or `CLAUDE.md`, and what the user said this session. Rank against that. No goal statement: say so and rank on risk and cost alone.
- The backlog files in scope.
- Per line, one shipped check: `git log --oneline --since=<its date> -i --grep=<topic words>` and, where the slug names a path, `git log` on it. A commit that plainly does the line's work makes it a deletion candidate, with the hash as evidence.
- A `when:` trigger that names a date or a count the session can check: whether it has fired.

Do not open `see:` paths or read code to rank. A line too vague to rank is reported as such.

## 2. Judge

Tags are the user's: P0 is important and urgent, P1 important and not urgent, untagged is P2. Rank within each tag; never move a line between tags yourself. Propose a change instead when the evidence says the tag no longer fits: a P1 whose deadline is now close, a P0 whose urgency has passed, a P2 with an irreversible loss at stake.

Within a tag:

**Importance** (what the result moves):
- S: an irreversible loss at stake (money on a path that sends, data, an account), a loss not bounded, a guard missing.
- A: moves the goal's own number measurably.
- B: stops a recurring incident or cost.
- C: hygiene, research with no decision riding on it, work outside the goal.

**Urgency** (what delay loses): a deadline (the last day the answer still leaves time for the work it enables; compute with `date` and name the weekday), bleed (each day of delay costs money or openings), or none.

Order: importance, then urgency (deadline, bleed, none), then the cheaper first. A decision the user owes inherits the importance and deadline of what it unblocks. No numeric scores.

Cleanup candidates, for one batch the user approves or edits:
- lines a commit already covers (hash and subject);
- untagged lines older than about 45 days that nobody started, or whose `when:` has not fired;
- lines that say the same thing (keep the clearer one);
- lines filed in the wrong scope (name the right one).

## 3. Present

In the user's language, on one screen:

1. "Your decisions": lines whose next step is the user's (a question, a go, an account or a key), ranked.
2. "For sessions": startable lines, ranked by tag then within it, grouped by scope when several are in play.
3. Waiting: lines with an unfired `when:`, one line each with the trigger.
4. Proposed tag changes, each with its reason.
5. The cleanup batch.

Each row: rank, tag, slug, the line's what, tier and urgency, cost in a few words.

Then offer the top line of up to three scopes as session cards (`start_session`, initiation `own_initiative`, context `fresh`) naming the slug and the line. Do not start an item yourself and do not commit.

## 4. Apply

On the user's answers: delete approved lines, change approved tags, move misfiled lines, and drop `when:` from lines whose trigger fired. Edit tool, one line per edit, keeping each file in tag order.
