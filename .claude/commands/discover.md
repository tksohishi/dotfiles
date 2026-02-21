# /discover: Find new Mac tools worth installing

Search the web for new and trending Mac tools, with a focus on developer tools used alongside AI coding agents (Claude Code, Codex, etc.). Filter out what's already installed and present the top 3 worth trying.

## Step 1: Search for trending tools

Use web search to find tools that are new or gaining traction in the last few months. Focus searches on:

- Tools that complement AI coding agents (MCP servers, terminal utilities, dev workflow tools)
- Hacker News discussions from the last 3 months
- Reddit (r/macapps, r/commandline, r/ClaudeAI) from the last 3 months
- General web: recent "best dev tools", "best CLI tools", "best MCP servers"

Prioritize tools that enhance the agent-assisted development workflow: better terminal output, smarter file management, MCP integrations, code review tools, etc. Include the current year in search queries to surface recent content.

## Step 2: Read the Brewfile

Read the `Brewfile` in this repo. Build a list of everything already installed (formulae, casks, and MAS apps).

## Step 3: Filter

Remove any tool that's already in the Brewfile. Also remove tools that:

- Don't support macOS
- Are abandoned or unmaintained (no updates in 2+ years)
- Are duplicates of something already installed with no clear advantage
- Are well-known staples that the user has likely already considered (e.g. fzf, bat, fd)

## Step 4: Deep-dive the top 3

Pick the 3 most interesting tools from what's left. For each one, research and write up:

- **What it does** (1-2 sentences)
- **Why people like it** (specific praise from threads/reviews)
- **How it compares** to alternatives or to what's already in the Brewfile
- **Drawbacks** (cost, resource usage, rough edges, limited scope)
- **Install method**: `brew install <formula>`, `brew install --cask <name>`, or MAS

## Step 5: Present results

Show the 3 tools in a numbered list using this format per tool:

```
### 1. ToolName
**What:** <description>
**Why people like it:** <specifics>
**vs. alternatives:** <comparison>
**Drawbacks:** <honest assessment>
**Install:** `brew install <name>`
```

After presenting, ask: "Want me to install any of these?"

If the user picks one or more, use the `/install` command workflow for each.
