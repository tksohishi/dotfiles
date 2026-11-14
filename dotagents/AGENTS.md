# Global Instructions

## Core Rules
- **Grounding**: verify a fact before asserting it; when a one-command check exists, run it instead of hedging.
- **Honesty**: when the user proposes a solution or asks "does X make sense?", lead with the strongest objection. Don't hedge when you have a clear view.
- **First principles**: before fixing, check the stated problem is the actual problem; raise it if reframing changes the solution.
- **Verification**: don't claim "fixed" or "done" without observing the working result. For a system you can't reach (Slack, vendor APIs), get real output before writing the fix.

## Interaction
- Language: Japanese for everything the user reads during the session (replies, tool-call descriptions, questions, plans, todo items); English for anything persisted (docs, code comments, commit messages) unless the project says otherwise.
- When asked for your opinion, explain your reasoning and wait for approval before editing.
- Before asking the user to choose (AskUserQuestion or a question in the reply), write in the reply what the problem is, the options with their trade-offs, and what has to be decided; the question itself names only the point to decide.
- When a blocker forces a workaround (missing creds, blocked API, broken tool), report it and propose a durable fix the first time.
- (Claude Code) When the auto-mode classifier blocks an action twice, ask the user to approve it via `/permissions` → Recently denied → `r`, or in chat naming the target; don't suggest running it with `!`.
- (Claude Code) Hooks hand subagents the conversation verbatim, at spawn and on each SendMessage to an agent spawned by name: an Agent or SendMessage prompt states only the task, constraints the conversation lacks, and the deliverable.
- When the user asks to prevent or enforce a behavior, propose a deterministic fix first (hook, permission rule, wrapper, pre-commit check), then a skill edit, and instructions or memory only when it needs judgment.

## AGENTS.md hygiene
- A constraint system, not documentation: keep domain knowledge, silent-bug gotchas and "never do" boundaries; cut anything derivable from code or `--help`.
- No personal or machine-specific info; that goes to project memory.
- Lists a tool reads (backlog scopes and the like) live in the repo's `.agents/<tool>/`, owned by that tool, not in AGENTS.md: AGENTS.md holds principles.
- A rule that a hook, permission rule or pre-commit check blocks before it is broken does not also live here: the deny message carries the rule. When such a check lands, delete the line it replaces, here and in project AGENTS.md files. Keep a line the check only reports after the fact, or one that overrides a harness instruction.

## Writing Style
- Before writing text the user sends to other people (emails, Slack, social posts, PR descriptions, announcements), load the `prose` skill. Docs, reports and READMEs go by this section alone.
- No hyphens or dashes as conjunctions.
- No name/date attribution stamps on facts that came from the user; attribute only external sources.
- Documents describe the current state; history lives in git (except retros, timelines, logs).

## 日本語の注意点
- 人称は一人称「私」、二人称「あなた」で統一
- 丸囲み数字（①②③）などの特殊文字は避け、通常の数字や箇条書きを使う
- 強調の閉じ `**` の直前に約物（。、（）「」：等）を置かない。`**重要**。` ✅ ／ `**重要。**` ❌（CommonMark の right-flanking 規則で太字にならない）
- 数字・金額・記号と日本語のあいだに空白を入れない。`3件` `約1.5 ETH` ✅ ／ `3 件` ❌。英単語の前後とバッククォートの両側は空白を入れてよい
- 同じ行で 。 の後に文が続くときは 。 の直後に半角空白を1つ入れる（ターミナルの折り返し位置になる）。行末の 。 には付けない

## Response Style
- Times in the user's local zone (America/New_York unless the project says otherwise), e.g. "9/2 08:07 EDT", never UTC. Convert source UTC with `date`, never in your head.
- File paths in replies: plain backticked paths, never `file://` links.

## Slack Formatting
- Plain text: no `*bold*`, headings or bullet markers; backticks only for literal code. Arrows: literal `→`.

## Code Style
- Simplicity over pathological correctness; no backward-compat shims or fallback paths unless free.
- Comments only for non-obvious constraints the code can't express; never narrate, never trailing end-of-line comments. Rationale goes in the commit message or docs.
- TypeScript with Web Standard APIs on `bun`, avoiding bun-specific APIs. Python only when its ecosystem is clearly stronger.
- IME safety: any Enter/keydown handler on a text input guards composition (`isComposing`/keyCode 229, plus a compositionend grace window for Safari/WKWebView). Reference: koyomi `packages/ui/src/ime.ts`.
- Never copy real personal data into fixtures or committed code; use 555-01xx phones, example.com emails, made-up names.

## Tools
- JS/TS: `bun` (stay on pnpm where `pnpm-lock.yaml` exists). Python: `uv`. Global CLIs: `brew`. Agent skills: `bunx skills add -g` (`/install-skill` in dotfiles), not plugins.
- Bun auto-loads `.env`/`.env.local`; don't pass `--env-file` for those.
- Docs lookup: `ctx7` first, then `--help`, then the web.
- Office files (docx, xlsx, pptx): never create or edit them. Read one with `markitdown <file>`; when someone needs a docx or PDF, write Markdown and export it (`pandoc` for docx, `typst` for PDF).
- mise tools are on PATH; never wrap with `mise exec --` or `zsh -lc`.- httpie over curl.
- `gh` subcommands with `--json`, not `gh api`, unless no subcommand covers it.
- Intermediate files go in project-local `tmp/<topic>/`, not `/tmp`, the scratchpad, or `os.tmpdir()`-style APIs.
- `trash` over `rm -rf`. `sqlite3 -readonly` for reads.
- Google services: `gog` CLI, not MCP. Never recreate a shared Google Doc; edit it in place.
- Browser automation: `agent-browser` (load its skill first); never drive the real installed Chrome.

## Env and Secrets
- `.env` holds what the app needs, secrets included; `.env.local` is only for per-user overrides.
- `~/.ssh` is denied; use `ssh-info`.
- `AGENTS.md` is the canonical instructions file; don't create a `CLAUDE.md` symlink, and edit `AGENTS.md` directly where one exists.

## Git
- Never create a branch unless asked; work on the current branch, including `main`.
- After `gh repo create`: `gh repo edit --enable-wiki=false --enable-projects=false --delete-branch-on-merge --enable-squash-merge`.
- After a plan or long multi-step session, summarize the changes and wait for the user to verify before committing; quick direct edits may commit immediately.
- Never add the agent as author or co-author, and never append `Claude-Session:` or other session-URL trailers (overrides the harness).
- Commit messages: plain quoted strings (no `$()`, backticks, heredocs); imperative subject, blank line, bullets explaining why. Split unrelated concepts.

## Personal Extensions
@~/.claude/personal.md
