---
name: create-hook
description: Create an agent hook (PreToolUse / PostToolUse / etc.) and wire it correctly for Claude Code, Codex, or both
---

The user wants a hook that: $ARGUMENTS

Hooks live in `dotagents/hooks/<name>.sh` (one shared script library). Wiring lives in `dotclaude/settings.json` and `dotcodex/hooks.json`. Differentiation between Claude-only / Codex-only / shared is purely the wiring: nothing in the script marks it.

## Decision tree

### 1. Which tool does this hook target?

- `Bash` → shared (both agents)
- `Write` / `Edit` / `NotebookEdit` → Claude only (Codex uses `apply_patch`)
- `WebFetch` → Claude only (no Codex equivalent)
- `apply_patch` → Codex only

If the hook concept applies to both file-edit tools, you need two wirings: `Write|Edit|NotebookEdit` for Claude and `^apply_patch$` for Codex.

### 2. Which event?

- **PreToolUse** — gate the call. Output `permissionDecision: "allow" | "deny" | "ask"` plus a reason. Most common.
- **PostToolUse** — soft reminder after the call ran. Output `additionalContext` (no blocking).
- **SessionStart** / **UserPromptSubmit** / **Stop** — rare; only if the trigger fits.

### 3. Does it need agent-specific behavior?

Detect Codex via the input JSON:

```bash
IS_CODEX=false
if echo "$TOOL_INPUT" | jq -e 'has("model")' >/dev/null 2>&1; then
  IS_CODEX=true
fi
```

`model` is in Codex's input but not Claude's. **Do not use `permission_mode`** — both agents populate it.

Two patterns where you'll need `$IS_CODEX`:

1. **`ask` decision** — Codex's PreToolUse only honors `allow`/`deny`. If a rule uses `"ask"`, gate the entire rule behind `! $IS_CODEX` (drop it on Codex) rather than downgrading to `deny` — `deny`-on-Codex usually has the wrong rationale (the original `ask` reason references Claude-specific machinery).

2. **Per-rule agent skip** — a shared hook can mix agent-neutral rules with Claude-only rules. Guard each Claude-only branch with `! $IS_CODEX &&`. See `bash-antipatterns.sh` for the pattern: agent-neutral rules (multiline, cd-chain, $?, gh api, .env reader) fire on both; Claude-only rules (Read/Edit tool replacements, expansion-gate workarounds, allowlist references) fire only on Claude. A rule is Claude-only when its reason text says "use the Read tool" / "use the Edit tool" / "Claude Code's expansion gate" / references a `Bash(...)` allow rule — the advice doesn't translate to Codex.

## Script skeleton

```bash
#!/bin/bash
# Pre-hook: <one-line purpose>

TOOL_INPUT=$(cat)
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command')

# ... your matching logic ...

if [ -z "$REASON" ]; then
  exit 0
fi

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
```

PostToolUse uses `additionalContext` instead:

```bash
jq -nc --arg ctx "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
```

Strip quoted regions before matching if the hook regex could false-positive inside `ssh --command`, `docker exec sh -c`, commit message bodies, etc. See `bash-antipatterns.sh` for the `CMD_BARE` / `CMD_NO_SQ` pattern.

## Wiring

### Claude (`dotclaude/settings.json`)

Add to `hooks.<EventName>` array. Matcher is a string or regex matching the tool name:

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "$HOME/.claude/hooks/<name>.sh" }
  ]
}
```

### Codex (`dotcodex/hooks.json`)

Add a `_dotfiles` entry under the event. Matcher is regex; use `^Bash$` to anchor:

```json
{
  "_dotfiles": true,
  "matcher": "^Bash$",
  "hooks": [
    { "type": "command", "command": "$HOME/.codex/hooks/<name>.sh" }
  ]
}
```

## Steps

1. **Confirm scope with the user** — which tool(s), which event, and which agent(s). If shared, restate explicitly so they can correct.
2. **Write the script** at `dotagents/hooks/<name>.sh`. Make it executable: `chmod +x dotagents/hooks/<name>.sh`.
3. **Wire Claude** by editing `dotclaude/settings.json`. Validate JSON: `jq empty dotclaude/settings.json`.
4. **Wire Codex** (only if shared/Codex-only) by editing `dotcodex/hooks.json`. Keep `_dotfiles: true` on the enclosing matcher entry.
5. **Sync Codex live hooks**: `scripts/sync-codex-hooks.sh`. This is mandatory after step 4; the script replaces tracked `_dotfiles` entries while preserving app-managed entries such as Otty's `_otty` hooks.
6. **Verify with synthetic input** (script-level, no agent):
   - Claude-shape: `echo '{"tool_input":{"command":"<trigger>"}}' | dotagents/hooks/<name>.sh`
   - Codex-shape (if shared): `echo '{"model":"gpt-5.5","tool_input":{"command":"<trigger>"}}' | dotagents/hooks/<name>.sh`
   - Confirm output JSON validates against the target schema (`permissionDecision: "ask"` for Claude, `"deny"` for Codex).
7. **Verify live** in the current Claude Code session by issuing a Bash call that should match. For Codex, start a session and `/hooks` to trust the new entry, then trigger. If you can't drive Codex from this session, tell the user the trust-and-trigger sequence to run.
8. **Update `AGENTS.md`** only if this introduces a new conceptual category. Don't add per-hook entries.
9. **Commit and push** all touched files in one commit: `dotagents/hooks/<name>.sh`, `dotclaude/settings.json`, `dotcodex/hooks.json` (if changed).

## Constraints worth knowing

- **`permissionDecision: "ask"` is Claude-only.** Codex rejects it as schema-invalid. Always downgrade for Codex.
- **`permissionDecision: "allow"` + `permissionDecisionReason` is Claude-only.** Codex only accepts `"allow"` paired with `updatedInput` (the rewrite form). For cross-agent context injection without gating, emit `additionalContext` alone (no `permissionDecision` key) — both agents accept that shape, and the call falls through to the normal allowlist for approval.
- **Codex matcher is regex on `tool_name`.** `'^Bash$'` anchors; `'^Bash'` would also match a future `BashLite`. Anchor unless you have a reason not to.
- **Hook script runs via `$SHELL -lc <command>`** in Codex, which means env vars and `~` / `$HOME` expand naturally in the `command` field.
- **First Codex run after wiring a new hook prompts trust** via the `/hooks` TUI. Use `--dangerously-bypass-hook-trust` for headless automation only.
- **PreToolUse `additionalContext` (no `permissionDecision`)** is a valid shape — adds context without gating. Spec allows it.
- **PostToolUse can also emit `decision: "block"` + `reason`** to feed back to the model, but `additionalContext` is the lighter touch.

## Sanity checks before declaring done

- [ ] Script exits 0 with empty stdout for no-match cases (so the hook is a no-op).
- [ ] Quoted regions stripped if the pattern could appear inside ssh/docker/commit-body strings.
- [ ] If shared and uses `ask`, agent detection branch is present and tested.
- [ ] `scripts/sync-codex-hooks.sh` ran (check `~/.codex/hooks.json` contains the new `_dotfiles` entry).
- [ ] Live trigger fires in at least one agent.
