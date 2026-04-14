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
