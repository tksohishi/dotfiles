---
description: "Initialize an Obsidian vault in the current project for browsing markdown files"
allowed-tools: [Bash, Read, Write, Edit]
---

# /obsidianize: Set up Obsidian vault

Initialize a `.obsidian/` directory in the current project with default settings optimized for read-only browsing of markdown files.

## Steps

1. Create `.obsidian/` directory if it doesn't exist
2. Write `.obsidian/app.json` with these settings:
   ```json
   {
     "defaultViewMode": "preview",
     "theme": "obsidian"
   }
   ```
   - `defaultViewMode: "preview"` = open notes in Reading view
   - `theme: "obsidian"` = dark mode
3. Add `.obsidian/` to the project's `.gitignore` if not already present
4. Report what was created
