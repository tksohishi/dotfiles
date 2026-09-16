# Claude mods

Claude Code plugins whose behaviour lives in a TypeScript hooks module
(`register(on)` over engine events). Claude-only: Codex has no equivalent
runtime, which is why these live here and not in `dotagents/`.

Early access: modules load only under `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1`,
and the API may change between releases. Until GA, load one by hand:

    CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 claude --plugin-dir dotclaude/mods/<name>

Tests run with the same flag:

    CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 claude plugin test dotclaude/mods/<name>

Types come from `/plugin-types` inside a session (written to
`.claude/types/claude-code.d.ts`); the source of the built-in mods is
https://github.com/anthropics/claude-code/tree/main/mods.

| Mod | What it does | Replaces |
| --- | --- | --- |
| `context-nudge` | Past 300K context tokens, and at each further 100K, logs the size and attaches a `/handoff` instruction beside the prompt; a compaction resets the band. Reads `$.session.usage()` instead of parsing the transcript. | `dotagents/hooks/context-size-nudge.sh` (kept wired until GA) |
