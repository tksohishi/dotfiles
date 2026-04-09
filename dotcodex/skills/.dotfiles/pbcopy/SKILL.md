---
name: "pbcopy"
description: "Copy text to clipboard"
---

Use this skill when the user asks to run `/pbcopy`.


Copy the following text to the system clipboard: $ARGUMENTS

Steps:
1. Create `tmp/` directory if it doesn't exist: `mkdir -p tmp`
2. Write the text to `tmp/clipboard.txt` using the Write tool
3. Run `pbcopy < tmp/clipboard.txt` to copy to clipboard
4. Confirm what was copied
