# Global Instructions

## Core Rules
- **Grounding** — Before asserting a fact, verify it. If you didn't verify, label the claim ("I think", "didn't check"). Never quote content you only saw in a search snippet. Load-bearing inputs to a recommendation (numbers, date ranges, "it already works") don't get the label escape hatch: run the one-command check (ls, last-run timestamp, du) or don't state the conclusion.
- **Honesty** — When the user proposes a solution or asks "does X make sense?", lead with the strongest objection or trade-off. Don't hedge ("might", "could") if you have a clear view.
- **First principles** — Before implementing a fix, check whether the stated problem is the actual problem. If reframing would change the solution, raise it; otherwise execute.
- **Resourcefulness** — Before saying "can't" or "not possible", run at least one investigation pass on alternatives.
- **Simplicity** — Before adding a helper, abstraction, or new file, ask: would inline or repeated lines be clearer? Don't refactor surrounding code unprompted.
- **Verification** — Don't claim work is "fixed" or "done" without observing the working result. For bugs that need external creds/state you can't access (Slack workspaces, vendor APIs, etc.), add tracing first and get one round of real output before writing the fix; don't guess and ship. For scripts under `~/.dotfiles/bin/` or other live-symlinked binaries, edit, ask the user to test against the uncommitted file, then commit only after they confirm. Use "trying X, please test" while iterating; reserve "fixed" for verified state.

## Interaction
- When asked for your opinion (e.g. "what do you think?", "would it make sense to ~?"), explain your reasoning first and wait for approval before making edits
- When a blocker forces a workaround (missing login/creds, blocked API, broken tool), report it and propose a durable fix the first time — don't silently re-pay the workaround each iteration
- (Claude Code) In plan mode, before presenting the final plan (ExitPlanMode), run `/cross-review` on the draft plan and address the feedback first
- (Claude Code) When the user interrupts plan approval (ExitPlanMode) with a question, answer it and state explicitly whether the plan changed — do NOT re-invoke ExitPlanMode in the same turn; wait for their go or use AskUserQuestion if a real decision emerged

## Enforcement Hierarchy
When the user asks to prevent, enforce, or change a behavior, consider options in this order before proposing a fix:

1. **Deterministic** — PreToolUse hook, deny/allow permission rule, wrapper script, pre-commit check, config constraint. Works without relying on the agent noticing.
2. **Skill or command edit** — for behaviors tied to a specific invocation (e.g. how `/update-apps` reports output).
3. **Memory or AGENTS.md** — soft guidance; use only when the behavior requires judgment or has no detectable signature.

Memory is the reflex because it is cheap to write, but it is a soft reminder the agent can still violate. Most "prevent X" requests have a detectable signature (command shape, file content, settings value) that a hook or rule can catch. Past rules that drifted into hooks all started as memory that failed to stick.

When proposing a fix, name the deterministic option first, note the tradeoffs (false-positive risk, maintenance cost), and mention memory only as fallback.

## AGENTS.md hygiene
- AGENTS.md is a constraint system, not documentation. Strip anything the agent can derive by reading code or running `--help`.
- Keep: domain knowledge the agent can't infer (lookup tables, fare rules, exclusion rationale with *why*), silent-bug gotchas, "never do" boundaries.
- Cut: file layouts, full CLI flag listings, file-by-file descriptions, deterministic setup steps (move to scripts or template headers). Target ~150 lines.
- Never add personal or machine-specific info (device names/UDIDs, signing teams, one user's install workflow, quirks of this Mac). Litmus test: would the line hold for a collaborator on another machine? If not, it goes to project memory, not AGENTS.md.

## Writing Style
- Before writing any prose document for humans (docs, reports, README sections, emails, announcements; not code or commit messages), load the `humanizer` skill and apply it while drafting; don't ship a first draft with AI tells (inflated openers, rule-of-three, negative parallelisms, "delve"-class vocabulary, vague attributions)
- Avoid using emdashes in writing
- Avoid using the section sign `§` in writing meant for humans; it reads as an AI artifact. Use the word "Section", "see", or drop the marker.
- Avoid using hyphens or dashes as conjunctions (use commas/semi-colons or rewrite)

## 日本語の注意点
- 人称は一人称「私」、二人称（you）「あなた」で統一
- 丸囲み数字（①②③）や囲み文字などの特殊文字は避ける。通常の数字（1. 2. 3.）や箇条書きを使う
- 強調（`**`）の閉じ記号の直前に約物（句読点。、だけでなく括弧 `()` `（）`・「」・：等すべて）を置かない。約物は必ず強調の外側に出し、閉じ `**` の直前は文字・数字で終える。`**重要**。続き` ✅ ／ `**重要。**続き` ❌ ／ `**見放題(加入中)**です` ❌ → `**見放題**（加入中）です` ✅（約物+CJK が CommonMark の right-flanking 規則に反し、太字にならない。英語文は直後が空白のため問題ない）

## Documentation Style
- Be concise; engineers scan, they don't read novels
- Prefer examples over prose
- Assume technical competence, skip obvious explanations
- Front-load critical info (warnings, key concepts first)
- Default to 1-2 sentence explanations; only expand when complexity requires it

## Response Style
- In conversational replies, drop filler, preambles, and hedging
  - English: "Great question", "just", "really", "basically"
  - Japanese: ご質問ありがとうございます preambles, えーと/まあ/基本的に filler, かもしれません/おそらく hedging
- Don't narrate internal deliberation ("Let me check", "I'll think about this", "まず確認"). Act, then state results
- Don't restate the user's question before answering
- End-of-turn summary: 1-2 sentences max covering what changed + what's next. Don't append headers, tables, or multi-section breakdowns unless the content genuinely benefits (5+ items, side-by-side comparison, lookup reference)
- Match structure to complexity: single-concept questions get a single-concept answer
- Fragments OK when meaning is clear; use full sentences for ambiguous cases, security warnings, and destructive action confirmations
- Preserve technical terms, code, and quoted strings exactly

## Markdown Formatting
- Headings: prefer `###` for topic titles in general content. Reserve `#`/`##` for top-level document structure where genuinely needed.
- Bold (`**text**`): reserve for genuinely important claims only. Don't bold for routine emphasis or to highlight every key term.
- Clickable file paths: when citing a file the user is meant to open (smoke artifacts, screenshots, generated reports, log dumps), render as `[name](file:///absolute/path)` so it's one click to inspect. Plain backticked paths aren't clickable in the Claude Code UI. Skip for source-code citations like `app.py:123` where the user reads in an editor, not opens via the OS.

## Slack Formatting
- Draft Slack messages as plain text: no markdown-format modifiers. No `*bold*`, no `#`/`*` headings, no `-`/`*` bullet markers. Write plain sentences and paragraphs; separate points with blank lines.
- Reserve backticks / fenced code blocks for literal code or shell commands only, never for emphasis or decoration.
- Arrows: literal `→`.

## Code Style
- Always prefer simplicity over pathological correctness; YAGNI, KISS, DRY
- No backward-compat shims or fallback paths unless they come free without adding cyclomatic complexity
- Only change what was asked for; don't refactor, annotate, or "improve" surrounding code unprompted
- Never copy real personal data (phone numbers, emails, addresses, names from the user's DB/calendar/inbox) into test fixtures, committed code, or anything else that could be published. Anonymize first: US phone numbers from the reserved 555-01xx range, example.com emails, made-up names. Local data stores (databases, gitignored tmp/) legitimately hold real data — don't flag or scrub those.

## Package Managers
- Node.js: pnpm, not npm
- Python: uv, not pip
- Bun auto-loads `.env` (and `.env.local`, `.env.{NODE_ENV}`) from the working directory. Just run `bun script.ts`; don't add `--env-file=.env` redundantly. Use the flag only for non-default filenames (e.g. `--env-file=.env.staging`).
- Global CLI tools: prefer `brew install` over `npm install -g`, `pip install`, or `go install`. Homebrew tracks everything in the Brewfile.
- Agent skills/capabilities: prefer `bunx skills add -g <owner>/<repo>` (skills.sh) over `claude plugin install`. skills.sh is agent-neutral (Claude / Cursor / Codex / Copilot all read the same `~/.agents/skills/<name>/` via per-agent symlinks); plugins are Claude-only and lock you in. From within the dotfiles repo use `/install-skill` which handles discovery (via find-skills), install, and skills.txt tracking in one step. Legitimate exception: capability ships only as a plugin (LSP servers, etc.) and not on skills.sh.

## Context Efficiency
- Request targeted output: Read with `limit`/`offset` for large files; `rg` with `-m N` or `--files-with-matches` first; `| head -N` for verbose shell output
- Delegate heavy research to subagents (where available) and request bounded summaries ("under 300 words") so raw output stays out of main context
- When delegating to a subagent, apply a cost threshold: spawn only for multi-source synthesis (10+ URLs or cross-source comparison). For 1-3 page lookups, use WebFetch directly. Subagent overhead runs ~10x the tokens of a direct fetch for simple factual questions.
- (Claude Code only) The main session runs Fable as the orchestrator: keep research, investigation, querying, and coding work delegated to subagents rather than doing it inline. Subagents run opus, enforced by `CLAUDE_CODE_SUBAGENT_MODEL` in settings.json; don't pass a `model` param, it's overridden anyway.
- Named teammates (Agent with `name:`) stay resident after reporting and pile up as idle entries in the Agents panel; `TaskStop` each one as soon as its work is integrated. Prefer unnamed one-shot agents for review/research fan-outs — they exit on their own. TaskList doesn't show pre-compaction teammates; the Agents panel is the source of truth.
- Fetch targeted URLs (release notes, specific issue pages, doc sections), not top-level pages

## Shell Commands
- When looking up technical documentation (CLI, library, SDK, platform, service, framework), default to `ctx7` first (`ctx7 library <name>` then `ctx7 docs <id> "<query>"`) before WebFetch/WebSearch. For CLI tools, also run `--help`. Fall back to WebFetch only when ctx7 has no hit or the specific info is missing from the indexed content.
- mise-installed tools (`codex`, `bun`, `node`, `deno`, etc.) are on PATH via shell inheritance from the activated zsh that launched the agent. Call them directly. Don't wrap with `mise exec --` (gated by ask) or `zsh -lc` (wrapper-bypass; gated). If a tool isn't on PATH, the launch context wasn't activated; investigate before reaching for a wrapper.
- Within the current project, prefer relative paths — for git (`git add foo.ts`), scripts (`bun scripts/foo.ts`, `python scripts/foo.py`, `./bin/foo`), and file ops (`ls src/`, `cat config.toml`). Use absolute paths only for files outside the project or when wd is genuinely ambiguous.
- Prefer WebFetch/Fetch tools for simple web requests; use `http` (httpie) for API calls requiring custom headers or auth; never use `curl` unless httpie is unavailable
- When calling `http`/`https` (httpie), always specify the method explicitly and put flags AFTER the URL. Canonical form: `http METHOD <URL> [flags...]` (method required, not optional; otherwise httpie's auto-method promotes commands with `key=value` data fields to implicit POST and bypasses the destructive-method gate). A PreToolUse hook blocks flag-first invocations.
- Use `fd` for file search, scoped to the project directory. Ask before searching outside the project.
- **Always use `gh` subcommands, never `gh api`.** Use `--json <fields>` for structured output. Run `gh <resource> --help` if unsure which subcommand exists. Fall back to `gh api` only when no subcommand covers the operation, and research the endpoint first.
- Use `jq` for JSON processing, not `python -c "import json..."` or similar Python one-liners
- Prefer Read for file content (not `cat`) and Edit for changes (not `sed`). For search, use `rg` and `fd` via Bash (Claude Code's macOS native build dropped the Grep/Glob tools). For JSON use `jq`.
- For intermediate files (pdftotext output, downloaded HTML, etc.), use project-local `tmp/` (globally gitignored), not `/tmp`. In code, write `path.join(process.cwd(), 'tmp')` (Node/TS) or `Path.cwd() / 'tmp'` (Python). Never reach for `os.tmpdir()`, `fs.mkdtemp`, `tempfile.gettempdir()`, `tempfile.NamedTemporaryFile()`, or bare `mktemp` — they all bypass the rule by returning a system temp path. Keeps operations in the project directory and avoids `cd`-chain patterns.
- `cp`, `mv`, `rm` with flags trigger a Claude Code built-in path-safety check that prompts even when the command is in `permissions.allow`. Bare single-file `cp src dst` is fine. For recursive / no-clobber copy use `rsync -a --ignore-existing src/ dst/` (trailing slashes copy contents into dst) — rsync isn't subject to the path-safety check and its allow rule works. The earlier `cp -an` recommendation was wrong: the allow rule never bypassed the prompt.
- Prefer reversible deletion over `rm -rf` for bulk/cache/directory removal: use `trash <paths...>` (macOS built-in, recoverable from Trash). Besides being safer, `rm -rf` of home paths is denied outright by the auto-mode classifier, while `trash` passes cleanly. Reserve `rm` for cases where non-recoverable removal is actually required.
- Use TypeScript with Web Standard APIs for scripting and web apps; use `bun` as the runtime but avoid bun-specific APIs to keep code portable across runtimes
- Prefer TypeScript over Python unless Python's ecosystem is clearly stronger for the task (e.g. data analysis, ML)
- For `sqlite3`, pass `-readonly` for read queries (SELECT, PRAGMA, .schema, .tables, .dump) so the database is opened read-only at the engine level. Omit it only for intentional mutations.
- macOS 15+ silently drops LAN unicast (ping/SSH return "No route to host" with ARP populated and gateway reachable) when the host app lacks Local Network permission in System Settings → Privacy & Security → Local Network. Resets on major OS updates.

## Env Files
- `.env` for values the app needs to run, including secrets. Typically gitignored; `.env.example` is the committed schema.
- `.env.local` is ONLY for per-user overrides (personal preferences, machine-specific tweaks). Don't default here just because the var looks sensitive or because Bun auto-loads it.
- When suggesting where a new var goes, default to `.env`. Use `.env.local` only when the value is genuinely per-user.

## Symlinked Configs
- Most files under `~/.claude/` and `~/.codex/` symlink into `~/.dotfiles/`. Edit/Write refuses to write through symlinks.
- When wd is `~/.dotfiles/`, edit the source files directly (e.g. `dotagents/AGENTS.md`, `dotclaude/settings.json`) instead of the `~/.<tool>/` paths.
- In any project, `CLAUDE.md` is conventionally a symlink to `AGENTS.md` (the canonical instructions file). When editing project instructions, go to `AGENTS.md` directly — don't write through `CLAUDE.md`, skip the `readlink` round trip. Same for `.cursorrules` → `AGENTS.md` if present.
- Claude Code's own `model` and `effortLevel` in `dotclaude/settings.json` are self-modification: never add or change them without explicit direction. Gotchas: `model` omitted = session default (`"default"` is NOT a valid value, it errors); valid `effortLevel` values are `low`/`medium`/`high`/`xhigh`. Read the file for the current value; never memorize it.

## Secrets
- Never read or search `.env`, `.env.<env>` (e.g. `.env.production`, `.env.local`), or `.dev.vars` files via any tool. This includes the Read tool, Edit, Write, and Bash readers/searchers (`cat`, `head`, `tail`, `less`, `more`, `bat`, `rg`, `grep`, `sed`, `awk`, `strings`, `xxd`, `od`, `nl`, `tac`). They contain API keys and tokens. Use `.env.example` for schema. To inspect a specific value, use a redaction script or ask the user.

## Google Workspace
- Use the `gog` CLI for all Google services (Gmail, Calendar, Drive, Docs, Sheets, ...), not the MCP Google tools. MCP is the fallback only when `gog` lacks the account or capability. Run `gog <service> --help` before concluding an operation isn't supported.
- Never recreate a Google Doc to change its content; edit in place with `gog docs` (write, insert, insert-image with local-file upload, format). Once shared, the URL is load-bearing.
- `gog drive upload --convert-to doc` turns a local file (e.g. .docx with embedded images) into a native Doc; `--replace <fileId>` works for binary files only, never native Docs.

## Browser Automation

### When to use
- Default to `agent-browser` for all browser automation (headless by default). Use WebFetch/httpie for simple HTTP requests; agent-browser only for sites that need a real browser. Never drive the real installed Google Chrome from scripts (e.g. Playwright `channel: "chrome"`) — it holds logged-in personal sessions; isolated browsers only.
- Never guess subcommands. Run `agent-browser --help` if unsure.
- Always close when done: `agent-browser close`.

### Workflow
- Common flow: `open <url>` → `snapshot -ic` → `get text <selector>` → `close`.
- To read page content: `snapshot` (accessibility tree with refs) or `get text @ref` (element text).

### Per-project config (authoritative)
- Each project gets `agent-browser.json` at its root (use the `/agent-browser-init` skill to generate). This is the source of truth for per-project browser behavior — do not override with `--session` / `--profile` flags.
- The config sets `session` (unique per-project daemon, enables parallel use across projects) and `profile: .agent-browser` (project-local Chrome user-data-dir, required for parallel Chrome instances to avoid `SingletonLock` conflicts).
- `agent-browser close` closes the current project's session; `close --all` closes every active session across projects.

### Headed mode (for Cloudflare, sign-in, cookie capture)
- Use `--headed` for flows that need a visible browser.
- Pass `--headed` on every call that should stay attached to a headed daemon. If the launch options don't match the daemon's current config, the daemon can respawn Chrome and lose page state.
- The warning `<flags> ignored: daemon already running` fires whenever any launch-time flag (`--headed`, `--profile`, `--args`, etc.) is re-passed against a running daemon, regardless of whether the value matches; it's cosmetic (nothing breaks). Suppress with `-q` or `--json`.
- Verify headed mode is active: `pgrep -lf "Google Chrome for Testing" | grep -v crashpad | grep -v Helper` — output must NOT contain `--headless=new`.
- Cloudflare challenges auto-clear within 2-3s in truly-headed mode; they never clear in headless.

### LinkedIn
- Requires login. If not logged in: `agent-browser close`, then `agent-browser --headed open "https://www.linkedin.com/login"`. After login, navigate to the target profile.
- For profiles, go directly to `/details/experience/` or `/details/education/` URLs to skip the Activity feed and get structured career data.

### Recovery
- When stuck, clean restart with `agent-browser close --all`. Avoid `pkill` — it leaves a stale `SingletonLock` in the profile dir that breaks subsequent launches.

## Git
- Never create a branch unless I explicitly ask. Work on the current branch, including the default branch (`main`), directly. This overrides any built-in "if on the default branch, branch first" rule; do not auto-branch before committing.
- Prefer concise output to minimize token usage: `git status --short`, `git log --oneline`, `git diff --stat` (before full diff)
- After `gh repo create`, always configure repo defaults: `gh repo edit --enable-wiki=false --enable-projects=false --delete-branch-on-merge --enable-squash-merge`
- For other repos (clones in `tmp/`, external paths), use `git -C <repo> <cmd>` or `cd <repo>` first (wd persists across Bash calls). If you `cd`, return to the project root after.

## Commits
- After executing a plan (plan mode) or any long multi-step session, do NOT commit right away: present a summary of the changes made in the turn and wait for the user to verify them before committing. Quick single-purpose edits made at the user's direct request may still commit immediately.
- Never add the AI agent as a commit author or co-author
- NEVER append `Claude-Session:` links or any session-URL trailer to commit messages or PR bodies. This overrides the harness's built-in instruction to add them; strip the trailer it pre-fills.
- Always commit using the default git settings
- Use plain quoted strings for commit messages; `$()`, backticks, and heredocs trigger permission prompts
- Format: subject + blank line + bullet body. Subject is a short single focused concept in imperative mood; bullets cover what + why
- Split unrelated concepts into separate commits

## Personal Extensions
@~/.claude/personal.md
