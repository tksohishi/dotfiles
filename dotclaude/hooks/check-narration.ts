#!/usr/bin/env bun
// Stop hook: checks the most recent assistant turn for tool calls without preceding narration.
// Logs violations to ~/.claude/turn-checks/YYYY-MM-DD.log. Silent on clean turns.

import { readFileSync, appendFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

type HookInput = {
  transcript_path: string;
  session_id?: string;
  hook_event_name?: string;
};

const chunks: Buffer[] = [];
for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
const input: HookInput = JSON.parse(Buffer.concat(chunks).toString("utf8"));

const transcript = readFileSync(input.transcript_path, "utf8")
  .split("\n")
  .filter(Boolean)
  .map((line) => JSON.parse(line));

// Find the last assistant turn (the one that just completed).
// Assistant messages can be split across multiple JSONL entries; gather the most recent contiguous block.
let lastAssistantEntries: any[] = [];
for (let i = transcript.length - 1; i >= 0; i--) {
  const entry = transcript[i];
  if (entry.type === "assistant" || entry.message?.role === "assistant") {
    lastAssistantEntries.unshift(entry);
  } else if (lastAssistantEntries.length > 0) {
    break;
  }
}

if (lastAssistantEntries.length === 0) process.exit(0);

// Flatten content blocks in order.
const blocks: Array<{ type: string; text?: string; name?: string; input?: any }> = [];
for (const entry of lastAssistantEntries) {
  const content = entry.message?.content ?? entry.content ?? [];
  if (Array.isArray(content)) {
    for (const b of content) blocks.push(b);
  }
}

// Check: every tool_use should have some non-empty text block before it in this turn.
const MONITORED_TOOLS = new Set(["Bash", "Edit", "Write", "NotebookEdit"]);
const violations: string[] = [];
let seenText = false;
for (const block of blocks) {
  if (block.type === "text" && block.text?.trim()) seenText = true;
  if (block.type === "tool_use" && MONITORED_TOOLS.has(block.name ?? "")) {
    if (!seenText) {
      const toolName = block.name;
      const preview = JSON.stringify(block.input).slice(0, 120);
      violations.push(`${toolName}: ${preview}`);
    }
    seenText = false; // reset: require new narration before next monitored tool
  }
}

if (violations.length === 0) process.exit(0);

const logDir = join(homedir(), ".claude", "turn-checks");
if (!existsSync(logDir)) mkdirSync(logDir, { recursive: true });

const today = new Date().toISOString().slice(0, 10);
const logPath = join(logDir, `${today}.log`);
const timestamp = new Date().toISOString();
const session = input.session_id ?? "unknown";
const lines = violations.map((v) => `[${timestamp}] session=${session} no-narration ${v}`).join("\n") + "\n";
appendFileSync(logPath, lines);

process.exit(0);
