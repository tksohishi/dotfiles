---
name: launchd-setup
description: Set up a macOS launchd LaunchAgent for unattended scheduled jobs that must run on a specific Mac (residential IP, local cookies/credentials, logged-in CLI sessions, locally-installed tools). NOT for in-session reminders (use CronCreate) and NOT for cloud-hosted recurring agents (use built-in /schedule). Use when the job needs an always-on Mac and its environment intact.
---

# launchd-setup

Reference for setting up macOS LaunchAgents for unattended scheduled jobs. Skim sections by header.

## Step 0 — Sanity check

Use launchd ONLY when all of these hold:

- Job needs residential IP (scraping Substack / Cloudflare-protected sources, etc.) OR local cookies / `.env` / logged-in CLI sessions (gcloud, gh, claude, codex)
- A specific Mac is reliably always-on at fire time
- User accepts a local-machine dependency

Pick a different mechanism when:

- Job runs fine on datacenter IPs → `/schedule` (cloud-hosted, cheaper, no Mac dependency)
- User wants an in-session reminder → `CronCreate`
- Target Mac may be asleep or offline at fire time → don't use launchd; either move to `/schedule` or use `caffeinate` / pmset wake schedules (separate concern)

Use AskUserQuestion only if the right choice is genuinely ambiguous from context.

## Step 1 — File layout

Three files in the project's `scripts/` directory:

```
scripts/
├── <name>.plist.template     # plist with __PLACEHOLDERS__
├── setup-launchd.sh          # renders + installs the plist
└── <wrapper>.sh              # the actual job
```

Rendered plist lands at `~/Library/LaunchAgents/<label>.plist`. **Machine-local, not in the repo.**

**Never symlink the template into LaunchAgents.** launchd parses the file at load; placeholder strings (`__REPO_DIR__`, etc.) break XML or get loaded literally.

## Step 2 — Naming

Use a reverse-DNS label with a domain you own. The user's reverse-DNS prefix conventions are in `~/.claude/personal.md` (already in context); follow those. Examples of label shape:

```
com.<owner>.<repo-or-job>.<frequency>
com.<owner>.<repo-or-job>
```

Match the plist filename to the label: `~/Library/LaunchAgents/com.<owner>.<job>.<freq>.plist`.

## Step 3 — plist template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.<owner>.<job>.<freq></string>
    <key>ProgramArguments</key>
    <array>
        <string>__REPO_DIR__/scripts/<wrapper>.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>__PATH__</string>
        <key>HOME</key>
        <string>__HOME__</string>
    </dict>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>9</integer>
        <key>Minute</key><integer>7</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

Critical points:

- **PATH and HOME must be baked in.** launchd inherits no shell PATH. `bash -lc` / `zsh -lc` do NOT reliably read the user's actual PATH on modern Macs (mise / Homebrew shims live in `.zshrc`). The only reliable mechanism is to capture `$PATH` and `$HOME` from the calling interactive shell at setup time and write them into `EnvironmentVariables`.
- **`StartCalendarInterval` is local time.** Not UTC. Confirm the target Mac's TZ matches expectation.
- **Avoid round minutes.** `:00` and `:30` cluster with everyone else's cron. Prefer `:07`, `:33`, `:17`, `:47`, etc.
- **Skip `StandardOutPath` / `StandardErrorPath`** when the wrapper does its own logging (Step 5). Mixing both produces split log streams.
- `RunAtLoad: false` unless you want the job to fire every time the agent reloads (login, setup re-run, etc.).

## Step 4 — setup-launchd.sh

```zsh
#!/usr/bin/env zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.<owner>.<job>.<freq>"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
TEMPLATE="$REPO_DIR/scripts/<name>.plist.template"

# Preconditions
[[ -f "$TEMPLATE" ]] || { echo "missing template: $TEMPLATE" >&2; exit 1; }
[[ -x "$REPO_DIR/scripts/<wrapper>.sh" ]] || { echo "wrapper not executable" >&2; exit 1; }

# Escape sed-special chars in substitution values:
# &  expands to the matched text
# |  is the chosen sed delimiter
# \  is the escape char itself
escape() { printf '%s' "$1" | sed -e 's/[\&|]/\\&/g'; }

REPO_ESC=$(escape "$REPO_DIR")
PATH_ESC=$(escape "$PATH")
HOME_ESC=$(escape "$HOME")

# Render
mkdir -p "$(dirname "$PLIST_DST")"
rm -f "$PLIST_DST"   # in case prior install was a symlink to the template
sed \
  -e "s|__REPO_DIR__|$REPO_ESC|g" \
  -e "s|__PATH__|$PATH_ESC|g" \
  -e "s|__HOME__|$HOME_ESC|g" \
  "$TEMPLATE" > "$PLIST_DST"

# Reload
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "Loaded $LABEL"
```

Why each piece:

- `#!/usr/bin/env zsh` — matches the user's interactive shell, so `$PATH` includes everything they expect
- `REPO_DIR=...$(cd ... && pwd)` — script can be run from anywhere
- `escape()` — `&` in a path expands to the matched text in sed replacement and corrupts the plist; same for the chosen delimiter `|` and the escape char `\`
- `rm -f "$PLIST_DST"` before writing — if a previous setup symlinked the template directly (anti-pattern but possible), writing through the symlink would clobber the template in the repo
- `launchctl unload ... || true` — first install has no existing plist; unload errors are expected and harmless

## Step 5 — wrapper.sh

```zsh
#!/usr/bin/env zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

LOG_DIR="$REPO_DIR/log"
mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/$(date +%Y-%m-%d).log" 2>&1

echo "=== $(date '+%Y-%m-%d %H:%M:%S') start ==="

# Idempotency: bail if today's output already exists
TODAY=$(date +%Y-%m-%d)
OUTPUT="$REPO_DIR/brief/$TODAY.md"
if [[ -f "$OUTPUT" ]]; then
    echo "already done for $TODAY; exiting"
    exit 0
fi

# ... actual job ...

echo "=== $(date '+%Y-%m-%d %H:%M:%S') end ==="
```

Why each piece:

- `set -euo pipefail` — any error aborts; uninitialized vars caught; pipe failures propagate
- `exec >> ... 2>&1` — all stdout/stderr from this point goes to the per-day log; subprocess output is captured too
- **Idempotency via completion-marker file** — handles double-fires from manual reruns, launchd retry-after-resume from sleep, accidental double `launchctl start`. The marker is whatever the job writes only on success (an output file, a sentinel `.done`, etc.)

## Step 6 — Verification

In order:

```bash
# 1. Smoke-test the wrapper with the user's interactive PATH
zsh scripts/<wrapper>.sh

# 2. Confirm registration
launchctl list | grep com.<owner>.<job>

# 3. Manually trigger via launchd (uses plist's PATH/HOME, not yours)
launchctl start com.<owner>.<job>.<freq>

# 4. Inspect schedule + last/next-fire time
launchctl print gui/$(id -u)/com.<owner>.<job>.<freq>
```

Step 3 is the truly informative test: if it works there but not in step 1's environment, you have a PATH issue. If step 1 works but step 3 doesn't, the plist's `EnvironmentVariables` are missing something.

## Gotchas

- **PATH/HOME not inherited.** Bake them into `EnvironmentVariables`. Don't rely on `bash -l` / `zsh -l`.
- **sed escaping.** `&`, `|`, `\` in REPO_DIR / PATH / HOME corrupt the plist if not escaped before substitution.
- **No symlinking templates** into `~/Library/LaunchAgents/`. launchd parses placeholder strings literally.
- **Local time, not UTC.** `StartCalendarInterval` follows the Mac's local TZ. Confirm if the Mac travels.
- **Round-minute clustering.** `:00` and `:30` are crowded. Stagger to `:07`, `:33`, etc.
- **`launchctl unload` errors on first install.** Suffix with `|| true`.
- **Target Mac TZ confirmation.** If the job is time-sensitive (market open, news cutoff), verify the Mac's TZ via `sudo systemsetup -gettimezone`.
- **Gitignore repo-internal logs and locks.** `log/`, `*.lock`, `*.done` markers should not be committed.

## Claude Code interaction (when the wrapper calls `claude -p`)

Headless `claude -p` silently errors on permission prompts; there's no interactive user to approve. Mitigations:

1. **Pre-allow needed Bash patterns** in either `.claude/settings.json` (committed, team-shared) or `.claude/settings.local.json` (per-machine, gitignored). Identify what to allow by running the wrapper interactively first and noting which prompts fire.
2. **Verify slash commands work** by running the same prompt once interactively — confirms argument parsing, plugin/skill availability, etc.
3. **`HOME` from `EnvironmentVariables`** is what makes `~/.claude/` credentials and settings discoverable. Without it, `claude -p` can't find auth.
4. **Cost / token budget** — headless invocations bill normally. For frequent jobs, use a constrained prompt and limit output (`--max-turns`, etc.).

## Removal

```bash
launchctl unload ~/Library/LaunchAgents/com.<owner>.<job>.<freq>.plist
rm ~/Library/LaunchAgents/com.<owner>.<job>.<freq>.plist
```

Repo-side files (`scripts/<name>.plist.template`, `setup-launchd.sh`, `<wrapper>.sh`) can stay if you might re-enable later. Otherwise delete and update `.gitignore` if any runtime artifacts (`log/`, marker files) are no longer relevant.
