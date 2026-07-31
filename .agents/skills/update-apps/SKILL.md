---
name: update-apps
description: Update all Homebrew packages and casks, and check for Mac App Store updates
---

## Run state

State lives at `.cache/update-apps/state.json` under the repository root. The `.cache/` directory is gitignored because this is persistent, machine-specific state, not repository content. Read it before launching the subagents; create the parent directory when needed, then write the state back after the report. Missing or unparseable file means first run — treat both fields as empty, don't error.

```json
{
  "claude_version": "2.1.207",
  "open_items": [
    {
      "id": "font-sf-pro-reinstall",
      "first_seen": "2026-07-13",
      "text": "font-sf-pro cask record purged — run `brew reinstall --cask font-sf-pro` yourself (needs password)",
      "check": "brew list --cask font-sf-pro >/dev/null 2>&1; test $? -ne 0"
    }
  ]
}
```

`claude_version` is the version whose changelog was last reported. `open_items` are the 🔴 action-required items still outstanding — see "Action required" below.

## Execution: one subagent per operation

Run every update operation inside a subagent so the verbose command output stays out of the main context. The main session only reads/writes state, runs the `open_items` checks, picks the "new & noteworthy" entries, and assembles the report from the summaries the subagents return.

Launch the four subagents below as unnamed one-shot Agent calls **in a single message** so they run concurrently — they touch disjoint tools. Subagents can't see this skill, so copy each block's instructions (including the rationale text) into its prompt verbatim, and tell each to return only a bounded summary: the lists the report needs plus any errors verbatim, never full command output.

### Homebrew subagent

All brew operations stay in this ONE subagent, run sequentially — brew holds a global lock, so never split brew steps across parallel agents. Include the repository root path in its prompt (it needs the Brewfile). Steps, in order:

1. `brew update` — refresh package index. Capture the `==> New Formulae` / `==> New Casks` names.
2. `brew bundle install --no-upgrade` — install any missing Brewfile entries without upgrading already-present ones (upgrades are handled by steps 3-4 for formulae/casks, auto-update for GUI casks, and `mas upgrade` manually for App Store apps)
3. `brew upgrade --formula` — upgrade all formulae
4. `brew upgrade --cask $(brew info --json=v2 --installed | jq -r '.casks[] | select((.auto_updates | not) and (.version != "latest")) | .token')` — upgrades only casks with no self-update mechanism (CLI casks like codex, 1password-cli, notion-cli; versioned fonts; libreoffice). Self-updating GUI casks (Cursor, VS Code, ChatGPT, ...) are deliberately excluded: a brew re-download re-quarantines the bundle, triggering a one-time Gatekeeper "downloaded from the internet" dialog on next launch, whereas in-app self-update is silent. The cost is that a self-updating app you never launch stays stale until you open it. `version :latest` casks (font-sf-pro, font-sf-mono-nerd-font-ligaturized) are also excluded: brew "upgrades" them by re-downloading and uninstalling the previous artifact, and for pkg-based ones (font-sf-pro) that uninstall runs sudo, which fails headlessly and purges the cask record while leaving files on disk. Reinstall those manually with `brew reinstall --cask <name>` when needed. Never add `--greedy` or run a bare `brew upgrade --cask`.
5. `agent-browser install` — update its browser binaries
6. Prune stale browser caches. Each tool accumulates versions on upgrade rather than replacing them, and none have built-in cleanup. For each cache root, list its versioned subdirectories, then delete all but the newest of each group. Group by the directory name prefix; rank by the version segment (numeric/semver where present, mtime otherwise). Delete with `trash <dirs...>` (macOS built-in, reversible), not `rm -rf` — the auto-mode classifier blocks recursive force-deletes of home paths, and `trash` keeps the prune recoverable from the Trash.
   - `~/.agent-browser/browsers/chrome-<semver>/` — keep highest semver
   - `~/Library/Caches/ms-playwright/chromium-<n>/`, `chromium_headless_shell-<n>/`, `firefox-<n>/` — keep highest-numbered of each prefix
   - `~/Library/Caches/ms-playwright/mcp-chrome-<sha>/`, `mcp-firefox-<sha>/`, `mcp-webkit-<sha>/` — keep most recently modified per browser
   - Don't touch `ffmpeg-*`, `mcp-chrome-profile`, or unsuffixed entries like `mcp-chrome`.
7. `brew cleanup` — remove old versions and free disk space

Also include this rule in its prompt: never strip `com.apple.quarantine` from bundled binaries. An earlier version of this skill swept `/opt/homebrew/Caskroom` and `/Applications` for bundled `rg` and cleared the flag, because codex's bundled `rg` used to trip a Gatekeeper "rg Not Opened" popup when `codex exec` ran headlessly. That is obsolete: codex no longer bundles `rg`, it uses the Homebrew ripgrep formula, and Homebrew bottles are never quarantined. The only binaries the sweep still matched were helpers inside notarized GUI apps (ChatGPT, VS Code, Cursor), where a quarantine flag on an embedded helper never produces a prompt once the outer app is approved, and clearing it just removes a working security control. (A freshly quarantined app *bundle* is different — it does show a one-time "downloaded from the internet" dialog on next launch; that's why step 4 excludes self-updating GUI casks rather than dequarantining them.) If a real Gatekeeper popup ever resurfaces, scope the fix to the specific CLI binary that caused it; don't reinstate a blanket sweep.

Have it return:

- Upgraded formulae with old → new versions, split into Brewfile entries vs transitive deps. It must cross-check each upgraded name with `rg -nw '<name1>|<name2>|...' Brewfile` and classify by whether it appears — the upgrade output looks identical for both. Past slip: deno was reported as a Brewfile upgrade when it's actually a transitive dep of summarize and yt-dlp.
- Brewfile entries newly installed by step 2
- Cask upgrades with old → new versions
- For each Brewfile package with a major version bump: a summary of breaking changes, new features, and deprecations from its GitHub release notes (e.g. `https://github.com/<org>/<repo>/releases/tag/v<version>`)
- The homepage URL from `brew info <name>` (the first URL line, above the `From:` Homebrew-formula line) for each upgraded Brewfile package
- The new formulae/casks names from step 1
- Bytes reclaimed: cache prune per location, and the `brew cleanup` total
- Any errors or warnings verbatim

### mise subagent

Run `mise upgrade`. Return each upgraded tool with old → new version (or "nothing upgraded"), plus any errors verbatim.

### Claude Code subagent

Pass the stored `claude_version` from the run state into its prompt. It runs `claude update`, determines the installed version, then always fetches the changelog from `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md` — Claude Code auto-updates between sessions, so checking only when `claude update` upgrades misses the case where the version moved silently.

It summarizes **only entries strictly newer than the passed `claude_version`**. This bound is the whole point: without it every run re-summarizes the same backlog of recent versions, which is noise the user has already read.

- Installed version equals the passed one — nothing moved. Return that in one line with no entries.
- No passed version (first run) — summarize the installed version's entry only. Never walk back through history to fill a backlog.

Cover new features, breaking changes, settings/hooks schema changes, and notable bug fixes. Skip trivial entries (typo fixes, internal refactors). Return the installed version plus the summarized entries; the main session then sets `claude_version` in the state to the installed version.

### Mac App Store subagent

Run `mas outdated`. Return pending updates (app id, name, current → new version), or "none". If any exist, the main session reports them in the `### 🍎 Mac App Store` section with a note to run `mas upgrade` (it requires a password). Informational only — never add them to `open_items`; if the user leaves one pending, the next run's `mas outdated` will surface it again on its own.

## What to report

Brewfile packages only. Transitive deps are omitted unless they had a **major version bump**, in which case surface them as informational. Also report Brewfile entries that were newly installed because they were missing locally. For each upgraded package, briefly note any notable changes (deprecations, breaking changes, new features) from the Homebrew subagent's summary. Warn that upgraded GUI apps may need a relaunch if they were running.

Check the Homebrew subagent's new formulae/casks list for interesting additions. Highlight any relevant to the user's setup (developer tools, terminal utilities, productivity apps) with a one-line description. Don't overwhelm; surface only genuinely interesting additions.

Link each tool name so the user can research it: render the name as a markdown link, e.g. `[pitchfork](https://github.com/jdx/pitchfork)`. Use the homepage URL the Homebrew subagent returned; for new & noteworthy picks it didn't cover, run `brew info <name>` in the main session (the first URL line, above the `From:` Homebrew-formula line). Prefer the project's GitHub repo when the homepage is a GitHub URL or you can readily identify the repo; otherwise link the homepage `brew info` reports. Don't guess a GitHub URL you haven't confirmed — fall back to the homepage.

## Report format

Structure the report as sections with the emojis below. Section headers are organizational only (no severity meaning). Inside sections, prefix individual items with a severity emoji ONLY when they need attention; routine items stay unprefixed.

### Section headers (use exactly these)

- `### 🔴 Action required` — every open action item, carried-over and new (see below). Goes first. Omit when there are none
- `### 📦 Brewfile formulae` — formula upgrades
- `### 🧺 Casks` — cask upgrades from `brew upgrade --cask`
- `### ⚙️ mise tools` — mise-managed tool upgrades
- `### 🤖 Claude Code` — include current version in the header, e.g. `### 🤖 Claude Code (2.1.148)`
- `### 🍎 Mac App Store` — pending mas updates (informational; never persisted to `open_items`)
- `### 🧹 Cleanup` — cache pruning and `brew cleanup` results
- `### ✨ New & noteworthy` — interesting new formulae/casks

Omit empty sections (e.g. if nothing was upgraded in mise, drop the section).

### Per-item severity

- 🔴 **Action required** — the user must do something (run a manual command requiring sudo/password, resolve a config conflict, etc.). Examples: `mas upgrade` needs the password, a breaking-change setting needs migration, a hook misconfiguration surfaced during update. These do NOT go inline in the topical sections; they all collect in the `### 🔴 Action required` section, and they persist across runs — see below.
- 🟡 **Worth attention** — inline in its topical section, informational but the user may want to know. Examples: major version bumps in Brewfile packages, Claude Code schema/hook changes that could affect existing config, new interesting tools worth trying, deprecations. Reported once, in the run that surfaces them; not carried over.
- (no emoji) — routine, inline in its topical section. Patch/minor bumps with no breaking changes, "up to date" results, cache stats, bug fixes the user doesn't need to act on.

Do NOT use green/✅ for routine items — absence of emoji means routine. Reserve emojis for signal.

### Action required: persistence

An action item is not done when it is reported; it is done when the user actually does it. So 🔴 items survive across runs instead of scrolling away.

Each 🔴 item gets an entry in `open_items`: a stable `id` (kebab-case, reused run to run so the same item doesn't duplicate), the `first_seen` date (`date +%F`), the one-line `text` to report, and — whenever the state is machine-detectable — a `check` shell command that **exits 0 while the item is still unresolved**.

Each run, in order:

1. Run every stored item's `check`. Non-zero exit means the user fixed it: drop it from `open_items` and note it once, in the `🧹 Cleanup` section, as resolved (routine, no emoji). An item with no `check` can't be auto-resolved, so it stays until the user says it is done.
2. Report the surviving items plus any new ones in `### 🔴 Action required`, each with the concrete command or edit that clears it. Annotate carried-over ones with `(open since <first_seen>)` so a stale item is visibly stale.
3. Write the merged list back to `open_items`.

Write a `check` wherever one exists — an unresolvable item nags forever, which is the failure mode this is meant to prevent. Examples: a settings migration is an `rg -q` for the stale key in the config file; a stale binary is a `--version` piped to `rg -q`.

Before adding a 🔴 item, confirm the problem is real on this machine — the state it describes exists, and the consequence actually follows from it. A recurring item that turns out to be a false positive is worse than no item: it trains the user to ignore the section. Verify first, then track.

If the user says an item is handled, acknowledged, or to stop reporting it (by `id` or plainly, e.g. "the CotEditor one is done"), drop it from `open_items` — even without a passing `check`, and even when its `check` still says open. Their say-so wins; don't argue with it.

### Example

```
### 🔴 Action required
- font-sf-pro cask record purged — run `brew reinstall --cask font-sf-pro` yourself (needs password)
- /simplify renamed to /code-review — update any scripts referencing /simplify (open since 2026-06-28)

### 📦 Brewfile formulae
- awscli 2.34.51 → 2.34.52 (patch)
- 🟡 deno 2.7.14 → 3.0.0 (major) — breaking changes to Deno.serve API
- summarize 0.15.2 → 0.16.1 (minor)

### 🤖 Claude Code (2.1.148)
- Bug fix: Bash tool exit code 127 regression resolved

### 🧹 Cleanup
- Resolved: font-sf-pro is reinstalled, no longer pending
- Pruned chrome-148.0.7778.178 → 341 MB reclaimed
- brew cleanup → 21.6 MB freed
```

The 🔴 bullets carry no emoji of their own — the section header already says action required. The `/simplify` item is a carry-over: it was first reported weeks ago, has no machine check, and stays until the user says it is handled.
