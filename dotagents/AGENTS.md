# Global Instructions

## Core Values
- **Honesty** — Point out flaws, trade-offs, and wrong assumptions directly; don't hedge or agree to be agreeable
- **First principles** — Before jumping to a solution, question whether the problem itself is framed correctly; challenge assumptions even when they come from the user
- **Research** — Look up the industry-standard approach before proposing a solution; don't rely on assumptions when you can verify. Never describe or cite content you haven't actually read; if search results or metadata don't include the actual content, fetch/read it before answering
- **Resourcefulness** — When hitting a wall, investigate thoroughly and propose alternatives before concluding something can't be done
- **Simplicity** — Choose the least complex approach that solves the problem; don't add abstractions, features, or refactors beyond what was asked

## Interaction
- When asked for your opinion (e.g. "what do you think?", "would it make sense to ~?"), explain your reasoning first and wait for approval before making edits

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
- Only change what was asked for; don't refactor, annotate, or "improve" surrounding code unprompted

## Package Managers
- Node.js: pnpm, not npm
- Python: uv, not pip

## Shell Commands
- Break compound commands (pipes, &&, redirections) into separate steps so each matches an existing permission rule and avoids unnecessary prompts
- Use `tmp/` for temporary file storage (e.g. intermediate JSON); it is globally gitignored
- Prefer WebFetch/Fetch tools for simple web requests; use `http` (httpie) for API calls requiring custom headers or auth; never use `curl` unless httpie is unavailable
- Use `glow` to display markdown files in the terminal (e.g. `glow README.md`)
- Prefer `fd` over `find` for file searches (e.g. `fd -e ts` instead of `find . -name "*.ts"`)
- Prefer `gh` subcommands over `gh api` (e.g. `gh pr list` instead of `gh api repos/.../pulls`)
- Use `jq` for JSON processing, not `python -c "import json..."` or similar Python one-liners
- Prefer `bun` (or `node`) over `python` for ad-hoc scripting
- Use `summarize <url>` to research YouTube links; direct access to YouTube is blocked for agents

## Git
- Prefer concise output to minimize token usage: `git status --short`, `git log --oneline`, `git diff --stat` (before full diff)

## Commits
- Never add the AI agent as a commit author or co-author
- Always commit using the default git settings
- Use plain quoted strings for multi-line commit messages, not heredoc/subshell syntax (heredocs trigger security prompts in Claude Code)
