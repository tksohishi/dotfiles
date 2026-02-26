#!/usr/bin/env bun

import { readdir, readFile, rm, mkdir, writeFile, unlink } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptFile = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptFile);
const rootDir = path.resolve(scriptDir, "..");

const sourceDir = path.join(rootDir, "dotclaude", "commands");
const geminiDir = path.join(rootDir, "dotgemini", "commands");
const codexSkillsDir = path.join(rootDir, "dotcodex", "skills", ".dotfiles");

function usage(): void {
  console.log(`Usage:
  bun scripts/agent-commands.ts sync
  bun scripts/agent-commands.ts create <name>
  bun scripts/agent-commands.ts delete <name>
  bun scripts/agent-commands.ts list

Source of truth:
  dotclaude/commands/*.md

Generated targets:
  dotgemini/commands/*.toml
  dotcodex/skills/.dotfiles/*/SKILL.md`);
}

function validateName(name: string): void {
  const pattern = /^[a-z0-9][a-z0-9._-]*$/;
  if (!pattern.test(name)) {
    throw new Error(`Invalid command name: ${name}\nAllowed pattern: ^[a-z0-9][a-z0-9._-]*$`);
  }
}

function escapeTomlBasic(value: string): string {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll('"', '\\"');
}

function escapeYamlDouble(value: string): string {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll('"', '\\"');
}

function stripWrappingQuotes(value: string): string {
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }
  return value;
}

type ParsedMarkdown = {
  frontmatter: string[];
  bodyLines: string[];
};

function parseMarkdown(content: string): ParsedMarkdown {
  const lines = content.replaceAll("\r\n", "\n").split("\n");
  if (lines.length > 0 && lines[0] === "---") {
    const end = lines.findIndex((line, i) => i > 0 && line === "---");
    if (end > 0) {
      return {
        frontmatter: lines.slice(1, end),
        bodyLines: lines.slice(end + 1),
      };
    }
  }

  return {
    frontmatter: [],
    bodyLines: lines,
  };
}

function trimTrailingBlankLines(lines: string[]): string[] {
  const next = [...lines];
  while (next.length > 0 && next[next.length - 1] === "") {
    next.pop();
  }
  return next;
}

function resolveDescription(name: string, parsed: ParsedMarkdown): string {
  const descriptionLine = parsed.frontmatter.find((line) =>
    line.trimStart().startsWith("description:"),
  );

  if (descriptionLine) {
    const raw = descriptionLine.replace(/^\s*description:\s*/, "").trim();
    const value = stripWrappingQuotes(raw);
    if (value.length > 0) {
      return value;
    }
  }

  const heading = parsed.bodyLines.find((line) => line.startsWith("# "));
  if (heading) {
    return heading.slice(2).trim();
  }

  return `Command: /${name}`;
}

async function generateGeminiCommand(name: string, description: string, bodyLines: string[]): Promise<void> {
  const outputPath = path.join(geminiDir, `${name}.toml`);
  const lines: string[] = [];

  lines.push(`description = "${escapeTomlBasic(description)}"`);
  lines.push('prompt = """');

  for (const line of bodyLines) {
    lines.push(escapeTomlBasic(line));
  }

  lines.push('"""');

  await writeFile(outputPath, `${lines.join("\n")}\n`, "utf8");
}

async function generateCodexSkill(name: string, description: string, bodyLines: string[]): Promise<void> {
  const skillDir = path.join(codexSkillsDir, name);
  const outputPath = path.join(skillDir, "SKILL.md");

  await mkdir(skillDir, { recursive: true });

  const lines: string[] = [];
  lines.push("---");
  lines.push(`name: "${escapeYamlDouble(name)}"`);
  lines.push(`description: "${escapeYamlDouble(description)}"`);
  lines.push("---");
  lines.push("");
  lines.push(`Use this skill when the user asks to run \`/${name}\`.`);
  lines.push("");
  lines.push(...bodyLines);

  await writeFile(outputPath, `${lines.join("\n")}\n`, "utf8");
}

async function removeGeneratedFiles(): Promise<void> {
  await mkdir(geminiDir, { recursive: true });
  await mkdir(codexSkillsDir, { recursive: true });

  for (const entry of await readdir(geminiDir, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith(".toml")) {
      await rm(path.join(geminiDir, entry.name));
    }
  }

  for (const entry of await readdir(codexSkillsDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      await rm(path.join(codexSkillsDir, entry.name), { recursive: true, force: true });
    }
  }
}

async function sourceCommandNames(): Promise<string[]> {
  if (!existsSync(sourceDir)) {
    return [];
  }

  const names = (await readdir(sourceDir, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => entry.name.slice(0, -3))
    .sort((a, b) => a.localeCompare(b));

  return names;
}

async function syncCommands(): Promise<void> {
  await removeGeneratedFiles();

  for (const name of await sourceCommandNames()) {
    const sourcePath = path.join(sourceDir, `${name}.md`);
    const raw = await readFile(sourcePath, "utf8");
    const parsed = parseMarkdown(raw);
    const bodyLines = trimTrailingBlankLines(parsed.bodyLines);
    const description = resolveDescription(name, parsed);

    await generateGeminiCommand(name, description, bodyLines);
    await generateCodexSkill(name, description, bodyLines);
  }
}

async function createCommand(name: string): Promise<void> {
  validateName(name);
  await mkdir(sourceDir, { recursive: true });

  const sourcePath = path.join(sourceDir, `${name}.md`);
  if (existsSync(sourcePath)) {
    throw new Error(`Command already exists: ${sourcePath}`);
  }

  const template = `---
description: Describe what /${name} should do
argument-hint: <args>
allowed-tools: [Read, Edit, Bash]
---

# /${name}

Describe the workflow for /${name}.
`;

  await writeFile(sourcePath, template, "utf8");
  await syncCommands();

  console.log(`Created: ${sourcePath}`);
}

async function deleteCommand(name: string): Promise<void> {
  validateName(name);

  const sourcePath = path.join(sourceDir, `${name}.md`);
  if (!existsSync(sourcePath)) {
    throw new Error(`Command does not exist: ${sourcePath}`);
  }

  await unlink(sourcePath);
  await syncCommands();

  console.log(`Deleted: ${sourcePath}`);
}

async function listCommands(): Promise<void> {
  for (const name of await sourceCommandNames()) {
    console.log(name);
  }
}

async function main(): Promise<void> {
  const [subcommand, arg] = Bun.argv.slice(2);

  switch (subcommand) {
    case "sync":
      await syncCommands();
      return;
    case "create":
      if (!arg) {
        usage();
        process.exit(1);
      }
      await createCommand(arg);
      return;
    case "delete":
      if (!arg) {
        usage();
        process.exit(1);
      }
      await deleteCommand(arg);
      return;
    case "list":
      await listCommands();
      return;
    default:
      usage();
      process.exit(1);
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
