---
description: Copy text to clipboard
allowed-tools: Write, Bash
argument-hint: <text to copy>
---

Copy the following text to the system clipboard: $ARGUMENTS

Steps:
1. Create `tmp/` directory if it doesn't exist: `mkdir -p tmp`
2. Write the text to `tmp/clipboard.txt` using the Write tool
3. Run `cat tmp/clipboard.txt | pbcopy` to copy to clipboard
4. Confirm what was copied
