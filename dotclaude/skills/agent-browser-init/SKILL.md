---
name: agent-browser-init
description: Set up agent-browser in the current project. Writes `agent-browser.json` and gitignores `.agent-browser/`. Use when enabling agent-browser in a project for the first time.
---

## What this does

Creates a minimal per-project `agent-browser.json` so agent-browser runs isolated from other projects on the same machine.

## Why this exists (read before editing the config)

agent-browser has **two different "session" concepts** that are easy to confuse:

| Field | Purpose |
|---|---|
| `"session"` | Spawns a **separate browser instance / daemon**. Use this for per-project isolation and parallel use. |
| `"sessionName"` | Auto-saves/restores cookies + localStorage by name **within one daemon**. Not for isolation. |

Without a per-project `"session"`, multiple projects share one daemon and leak state across each other.

**`profile` is required for parallel use.** Chrome puts a `SingletonLock` on its user-data-dir; two Chrome instances can't share one dir. If two projects both use agent-browser concurrently without unique `profile` paths, the second one fails with:

```
Failed to create ~/.agent-browser/chrome-profile/SingletonLock: File exists
Aborting now to avoid profile corruption.
```

Pinning `profile` to a project-local `.agent-browser/` directory gives each project its own user-data-dir, so they coexist.

## Steps

1. **Check the current directory looks like a project root.** Confirm with the user if unclear (e.g. presence of `.git/`, `package.json`, `Cargo.toml`, etc.).

2. **Pick a session name.** Default: the basename of the current directory. Confirm with the user only if the basename is generic (`tmp`, `test`, `project`, etc.) or collides with an obvious conflict.

3. **If `agent-browser.json` already exists**, read it and diff the proposed content. Do not overwrite without user approval.

4. **Write `agent-browser.json` at project root** (it MUST be at root — agent-browser only auto-discovers `./agent-browser.json`, not nested paths):

    ```json
    {
      "session": "<session-name>",
      "profile": "./.agent-browser"
    }
    ```

    The leading `./` is **required**. agent-browser's `--profile <name|path>` heuristic treats bare strings without a path separator as Chrome profile names and fails with `Chrome profile ".agent-browser" not found`. Any string containing `/` is treated as a directory path. `./.agent-browser` is the minimal portable form; an absolute path also works but makes the config non-portable.

5. **Add `.agent-browser/` to `.gitignore`** (create the file if missing). Skip if already present. Do not add `agent-browser.json` itself — that's checked in so collaborators get the same config.

6. **Report to the user:**
    - Session name chosen
    - `agent-browser open <url>` works immediately; `.agent-browser/` is created on first launch
    - To run in parallel with other projects, nothing extra needed
    - `agent-browser close` closes only this session; `agent-browser close --all` closes every active session

## Do not

- Do not put the config inside `.agent-browser/` — agent-browser does not look there.
- Do not set `"sessionName"` unless the user explicitly wants cookie/localStorage auto-persistence (rare; most projects want fresh state per run).
- Do not set `"headed": true` by default. Headless is the right default; headed has macOS-specific gotchas (see global CLAUDE.md).
