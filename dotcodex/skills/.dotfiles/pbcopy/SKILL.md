---
name: "pbcopy"
description: "Copy text to clipboard"
---

Use this skill when the user asks to run `/pbcopy`.


Copy the following text to the system clipboard using `printf '%s' "<text>" | pbcopy` (double-quote wrapping so apostrophes don't break). If the content contains any of `" $ ` \`, fall back to writing a tmp file and piping with `pbcopy < <file>`.

Text: $ARGUMENTS
