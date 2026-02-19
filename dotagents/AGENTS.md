# Global Instructions

## Problem Solving
- Before proposing a solution, research the industry-standard approach to the problem and use it to inform your recommendation
- When the user's prompt asks for your opinion (e.g. "what do you think?", "how about ~?", "would it make sense to ~?"), do NOT apply changes immediately. Explain your reasoning first and wait for approval before making edits

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

## Commits
- Never add the AI agent as a commit author or co-author
- Always commit using the default git settings
