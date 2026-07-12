---
name: perfcheck
description: Run a quick macOS performance check (load, CPU, memory, thermal) and summarize anomalies. Use when the user asks to check machine performance, slowness, or load.
---

Run these commands as **separate** Bash calls (not chained) so each result is reviewable on its own:

1. `sysctl -n hw.ncpu hw.physicalcpu hw.memsize` — hardware baseline
2. `uptime` — load averages (compare against CPU count from step 1)
3. `memory_pressure | tail -15` — memory pressure and swap activity
4. `pmset -g therm` — thermal / power warnings
5. `ps -Ao %cpu,%mem,rss,comm -r | head -11` — top CPU consumers
6. `ps -Ao %cpu,%mem,rss,comm -m | head -11` — top memory consumers

Then summarize:
- **Load:** flag if 1m or 5m average exceeds physical CPU count
- **Memory:** flag if compressor pages are large or swapouts are active now (not just lifetime totals)
- **Thermal:** flag any warnings other than "No thermal warning level has been recorded"
- **Top consumers:** name the processes, don't just dump the table

Keep the summary tight. If nothing is anomalous, say so in one sentence.

## fileproviderd churn

`fileproviderd` pegged at high CPU alongside busy Finder (often with Dropbox or iCloud in the process list) means a wedged file-provider sync domain, not a runaway app. Diagnose before restarting anything:

1. `fileproviderctl dump -l` — look for a domain with a hot indexing scheduler (high registration count per minute) and `fetch-content` entries stuck with `itemNotFound` errors hours or days old.
2. `fileproviderctl check` (read-only FPCK; run in background, takes minutes) — reports per-domain consistency, e.g. `❌ disk <-> FSSnapshot failed on N/M files.` under a domain name. The failing domain names the culprit; don't trust the process list alone (Dropbox at 0% CPU can still be the broken domain while fileproviderd burns on its behalf).

Fix ladder, per failing domain:
- iCloud (`Mobile Documents`): `killall fileproviderd bird` — both respawn via launchd. Expect ~5 min of startup re-indexing before judging.
- Dropbox (or another third-party provider): restart that app — `osascript -e 'quit app "Dropbox"'`, wait a few seconds, `open -a Dropbox` (retry once on LSOpen error -600; it races the quit). The client re-baselines its domain on launch.
- Still pegged after both: the user does it in the provider app itself (Dropbox sign out/in, iCloud Drive toggle). Don't script that.

## Leave the machine in a good state

If any intervention was made (daemon kill, app restart, process kill), verify before finishing:

1. Confirm restarted daemons/apps are running again (`pgrep`).
2. Re-sample the original symptom over a few minutes (Monitor with 1-2 min samples, not one instant reading — startup re-indexing looks identical to a persisting wedge in a single sample). Report before/after numbers.
3. `uptime` once more; note whether load is trending down.
4. Stop any Monitor/background tasks this run started; leave no pollers running.

If the symptom persists after the fix ladder, say so plainly and hand the next step to the user rather than escalating to destructive options.
