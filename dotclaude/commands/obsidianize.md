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
3. Write `.obsidian/core-plugins.json` disabling sync:
   ```json
   ["file-explorer", "global-search", "graph", "backlink", "outgoing-link", "page-preview", "tag-pane"]
   ```
   This list enables only useful read-only plugins. Sync is excluded (disabled by omission).
4. Add `.obsidian/` to the project's `.gitignore` if not already present
4. Open the vault: `open "obsidian://open?path=<absolute-path-to-current-directory>"`
5. Report what was created
