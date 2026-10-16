---
name: postmortem
description: Write a blameless postmortem into the affected project's docs/postmortems/ covering what happened, why it happened, and the phased fixes (mitigate, prevent, detect), grounded in the session transcript, logs and git rather than recollection. Use when the user runs /postmortem [topic], or asks for a postmortem, incident review, root-cause write-up, ポストモーテム or 振り返り on something that broke, whether a real system incident (outage, data loss, bad deploy) or an agent session that went wrong.
model: opus
---

# postmortem

Writes `<repo>/docs/postmortems/<YYYY-MM-DD>-<slug>.md`. The format follows the blameless postmortem used in SRE practice: the question is never "who slipped" but "why did the system let this happen, and what change makes it impossible or visible next time". A postmortem whose action items are "be more careful" has failed.

If the incident is still ongoing, mitigate first and write afterwards. Say so instead of starting the document.

## Where it goes

- The repo of the system that broke (`git rev-parse --show-toplevel`). Create `docs/postmortems/` if missing.
- Agent-behavior incidents (a rule ignored, a destructive command run, a hook that let something through) are fixed in agent config, so the document goes in `~/.dotfiles/docs/postmortems/`.
- Filename: incident date (`date +%F`, or the date it happened) plus a short kebab-case slug. Never overwrite; pick another slug.
- Check visibility with `gh repo view --json visibility`. In a public repo (the dotfiles repo is public), write nothing personal: no real names other than the user's role, no emails, tokens, hostnames, private URLs or customer data. Describe them generically.

## Establish the facts first

The session that caused the incident is the worst narrator of it. Build the timeline from records:

- This session's own incident: the transcript is in context, but quote commands, errors and outputs verbatim from it rather than paraphrasing.
- An earlier session: delegate reading its JSONL under `~/.claude/projects/<dir>/` to a subagent, asking for a timestamped event list with verbatim commands and errors (under 400 words).
- Logs, `git log`/`git reflog`, CI runs, command output, file timestamps. Re-run read-only checks to confirm the current state.
- Convert every time to the user's local zone with `date`; never in your head.
- Anything not confirmed from a record is labeled unverified with what would settle it.

## Root cause

- Separate the trigger (the action that set it off) from the root cause (why that action was possible, or why it did damage).
- Ask "why" until the answer lands on something changeable: a config, hook, permission rule, script, skill, instruction, test or process. "The agent made a mistake" and "human error" are not root causes; the question is why nothing stopped or caught it.
- List contributing factors separately (stale docs, a misleading error message, missing test). Note where you got lucky: what would have made it worse and did not happen.

## Action items, in phases

1. **Mitigate**: what restored a working state. Usually already done in the session; record what was done and verify it holds.
2. **Prevent**: stop recurrence. Follow the enforcement hierarchy: a deterministic fix first (PreToolUse hook, permission rule, wrapper script, pre-commit check, test, config constraint), then a skill or command edit, and memory or AGENTS.md only when the behavior has no detectable signature. Say why a softer option was chosen when it is.
3. **Detect**: make a recurrence visible sooner (a check in a recurring skill, a test, a statusline or log signal), for the case where prevention misses.

Every item names the file or system it changes, and where possible a `check` shell command that exits 0 while the item is still unresolved, so its state can be re-verified later without rereading the document.

## Document

Load the `humanizer` skill before drafting. Write in the language the session was conducted in. This is a history document, so dated narration is expected. No em dashes.

Frontmatter:

```yaml
---
date: 2026-10-16          # when the incident happened
severity: medium          # high: data loss, security, or effect outside the machine; medium: broken workflow needing manual recovery; low: near miss, caught before harm
status: open              # done once every action item is done
touches: [dotagents/hooks/foo.sh]   # paths the action items change; verify each exists or is to be created
---
```

Sections, in order, dropping empty ones:

1. **Summary**: what broke, for how long, the impact, and the one-line root cause. Three to five lines.
2. **Impact**: what was lost, broken or put at risk, with numbers where they exist.
3. **Timeline**: local-time events from first cause to resolution, including when and how it was noticed.
4. **Root cause**: the why chain, ending at the changeable cause.
5. **Contributing factors**
6. **What went well / where we got lucky**
7. **Action items**: a table with phase, action, where, check, status (`open`, or `done <hash>`).
8. **References**: commits, logs, files, transcript paths.

## Review

For medium or high severity, run `/cross-review` on the root cause and action items before finalizing, and fold in what holds up. Skip for low severity.

## After writing

Reply with the clickable path (`[name](file:///abs/path)`), the one-line root cause and the open action items, then ask which to implement now. Don't implement prevent or detect items before the user picks. Commit the document per the project's commit rules. When an item lands, set its status to `done <hash>`, and set the frontmatter `status: done` once none are open.
