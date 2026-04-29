#!/usr/bin/env bun
import { readFileSync } from "fs";
import { parseArgs } from "util";

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    to: { type: "string" },
    cc: { type: "string" },
    bcc: { type: "string" },
    subject: { type: "string" },
    "body-file": { type: "string" },
    attach: { type: "string" },
    "reply-to-message-id": { type: "string" },
    quote: { type: "boolean" },
    account: { type: "string", short: "a" },
  },
  strict: true,
});

if (!values.to || !values.subject || !values["body-file"]) {
  console.error(
    "Usage: bun draft.ts --to <email> --subject <subj> --body-file <html-file> " +
      "[-a <account>] [--cc <emails>] [--bcc <emails>] [--attach <file>] " +
      "[--reply-to-message-id <id>] [--quote]",
  );
  process.exit(1);
}

const html = readFileSync(values["body-file"], "utf-8");

const args = [
  "gmail", "draft", "create",
  "--to", values.to,
  "--subject", values.subject,
  "--body-html", html,
];

if (values.cc) args.push("--cc", values.cc);
if (values.bcc) args.push("--bcc", values.bcc);
if (values.attach) args.push("--attach", values.attach);
if (values["reply-to-message-id"]) args.push("--reply-to-message-id", values["reply-to-message-id"]);
if (values.quote) args.push("--quote");
if (values.account) args.push("-a", values.account);

const proc = Bun.spawn(["gog", ...args], { stdout: "inherit", stderr: "inherit" });
await proc.exited;
process.exit(proc.exitCode ?? 1);
