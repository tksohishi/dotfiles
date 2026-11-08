---
name: bg-check
description: List this session's background work (shell tasks, Monitors, subagents and teammates, CronCreate jobs, /loop wakeups, scheduled tasks and routines, sessions it started) in one table with purpose, start time and whether it is still needed, and offer the stale ones for stopping; `/bg-check repo` adds every session in this repo, `/bg-check all` every session on the machine plus the claude daemon and leftover agent processes. Use when the user runs /bg-check [repo|all], or asks what is running in the background, "background tasks どうする", "裏で何が動いてる", or whether old jobs are still alive. Claude Code only. Read-only until the user approves a stop.
---

# Background check

The user asks about background work because stale jobs keep firing after their purpose is gone. A partial answer is the failure mode: checking shell tasks and `ps` alone missed a CronCreate job that kept sending requests. Check every source in scope in one pass, even when an earlier one already found something.

Scope comes from the argument: none is this session only (steps 1-2), `repo` adds step 3 with `--repo`, `all` adds step 3 machine-wide. "Other sessions" or "everything" in the user's words means `all`.

## 1. Load the deferred tools

Run one `ToolSearch` with `select:CronList,CronDelete,TaskStop,ListAgents,RemoteTrigger`. Skip names the result says are unavailable. In the desktop app, also look for `mcp__scheduled-tasks__list_scheduled_tasks` and `mcp__ccd_session_mgmt__list_sessions` in the tool list (or `ToolSearch` for `scheduled tasks` and `list sessions`); they exist only there.

## 2. Check this session's own sources

| Source | How to read it | Stop with |
|---|---|---|
| Shell tasks (`run_in_background`) and Monitors | `ls -lt` the `tasks/` folder next to this session's scratchpad (`/private/tmp/claude-<uid>/<project>/<session-id>/tasks/`); for each `.output`, its last write time, and `lsof <file>` to see whether a process still holds it (then `ps -o etime= -p <pid>` for its age) | `TaskStop` with the task ID (the file name) |
| Subagents and named teammates | `ListAgents`; this session's own agents and teammates, busy or idle | `TaskStop` with the name or agent ID |
| CronCreate jobs | `CronList` | `CronDelete` with the job ID |
| `/loop` wakeups | No list tool: read this session's transcript (`~/.claude/projects/<project>/<session-id>.jsonl`) for the last `ScheduleWakeup` call; pending unless its input has `stop: true` | `ScheduleWakeup` with `stop: true` |
| Scheduled tasks (desktop) | `list_scheduled_tasks` | that MCP's own delete or disable |
| Routines | `RemoteTrigger` `list`, then `get` for `enabled` and `next_run_at` | `RemoteTrigger` `update` with the user's change |
| Sessions this session started (desktop) | `list_sessions`, the rows linked to this session | the session's own close |

For each item, the purpose comes from the call that created it: the task description, the cron prompt, the agent's task, the routine's prompt. Read it from the transcript when the listing doesn't say. Convert every time to the user's local time with `date`.

## 3. Other sessions (`repo` or `all` only)

Run `bg-scan --repo <repo root>` for `repo`, `bg-scan` for `all` (dotfiles bin). It reads what this session's tools cannot see:

- background shells and Monitors of other sessions that still have a live process
- CronCreate jobs never deleted, per session, with their last fire time. A job lives only as long as its session, so one whose transcript stopped updating days ago died with it: list it as gone, not as a stop candidate
- leftover Claude worktrees, with uncommitted and unpushed counts
- `all` only: the `claude` daemon and its background sessions, and long-running `patchright-fetch` windows, `codex exec` reviews, headless `claude -p` runs and Chrome for Testing

Skip rows that belong to this session; step 2 already has them. Another session's shell task or cron job can only be stopped from that session: offer to ask it with `/ask` (SendMessage), or `kill <pid>` for a bare process.

## 4. Report

One table, every source listed even when empty (write "none"), so the user sees that it was checked:

| Kind | ID | Purpose | Started | Last activity | Still needed? |
|---|---|---|---|---|---|

"Still needed?" is your judgment with its reason, such as "no: the logGC run it watches finished 11/08 09:10". Under the table, name the ones you would stop.

## 5. Stop only with approval

Ask with AskUserQuestion which candidates to stop, one option per item plus "keep all". Stop exactly the approved ones, then list each source again and show that they are gone. A routine or scheduled task outlives this session and may serve another project: say so when offering it.
