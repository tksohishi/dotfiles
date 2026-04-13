---
description: Copy text to clipboard
allowed-tools: Bash
argument-hint: <text to copy>
---

Copy the following text to the system clipboard using `printf '%s' "<text>" | pbcopy` (double-quote wrapping so apostrophes don't break). If the content contains any of `" $ ` \`, fall back to writing a tmp file and piping with `pbcopy < <file>`.

Text: $ARGUMENTS
