# /discover: Find new Mac tools worth installing

Search the web for trending Mac tools (CLI and GUI), filter out what's already installed, and present the top 3 worth trying.

## Step 1: Search for trending tools

Use web search to find recently popular or recommended Mac tools from these sources:

- Hacker News (e.g. "best new mac tools", "mac cli tools")
- Reddit: r/macapps, r/commandline
- General web: "best new mac apps 2026", "best new command line tools 2026"

Cast a wide net. Collect tool names, what they do, and where you found them.

## Step 2: Read the Brewfile

Read the `Brewfile` in this repo. Build a list of everything already installed (formulae, casks, and MAS apps).

## Step 3: Filter

Remove any tool that's already in the Brewfile. Also remove tools that:

- Don't support macOS
- Are abandoned or unmaintained (no updates in 2+ years)
- Are duplicates of something already installed with no clear advantage

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
