# Global Instructions

## Problem Solving
- Before proposing a solution, research the industry-standard approach to the problem and use it to inform your recommendation
- When the user's prompt asks for your opinion (e.g. "what do you think?", "how about ~?", "would it make sense to ~?"), do NOT apply changes immediately. Explain your reasoning first and wait for approval before making edits

## Reasoning
- Be honest over agreeable; if an approach has flaws, say so directly instead of hedging with qualifiers
- Before diving into implementation, step back: is the problem framed correctly? Challenge assumptions and ask "why" before "how"
- When something looks infeasible, investigate thoroughly before concluding. Offer alternatives when the direct path won't work; focus on what can be done

## Writing Style
- Avoid using emdashes in writing
- Avoid using hyphens or dashes as conjunctions (use commas/semi-colons or rewrite)

## Documentation Style
- Be concise; engineers scan, they don't read novels
- Prefer examples over prose
- Assume technical competence, skip obvious explanations
- Front-load critical info (warnings, key concepts first)
- Default to 1-2 sentence explanations; only expand when complexity requires it

## Code Style
- Always prefer simplicity over pathological correctness; YAGNI, KISS, DRY
- No backward-compat shims or fallback paths unless they come free without adding cyclomatic complexity
- Use pnpm, not npm, for all Node.js package management (install, run, exec, etc.)

## Shell Commands
- Break compound commands (pipes, &&, redirections) into separate steps so each matches an existing permission rule and avoids unnecessary prompts
- Use `tmp/` for temporary file storage (e.g. intermediate JSON); it is globally gitignored
- Prefer WebFetch/Fetch tools over `curl`; only fall back to `curl` when the tool is unavailable
- Use `glow` to display markdown files in the terminal (e.g. `glow README.md`)
- Prefer `gh` subcommands over `gh api` (e.g. `gh pr list` instead of `gh api repos/.../pulls`)

## Commits
- Never add the AI agent as a commit author or co-author
- Always commit using the default git settings
- Use plain quoted strings for multi-line commit messages, not heredoc/subshell syntax (heredocs trigger security prompts in Claude Code)
