---
name: ask
description: Send a request to another running Claude Code session on this machine (ListAgents to find it, SendMessage to deliver it). Use when the user runs /ask <session> [what], or says to tell, ask or pass something to another session ("lynx セッションで検討して", "degen-app に伝えて", "tell the dotfiles session"). The session name is matched loosely; the request text is composed from the conversation.
---

# ask

Claude Code only: Codex has no ListAgents or SendMessage, so there it says so and stops.

## Find the session

1. Run ListAgents. Load SendMessage with ToolSearch (`select:SendMessage`) if its schema is not loaded.
2. Match the user's word against the rows, loosely: exact name, then a name containing the word (`lynx` → `degen-lynx`), then the word plus this project's name. When more than one row matches, prefer the one in the current project's name family; still tied, ask with AskUserQuestion listing the candidates and each one's state.
3. Never send to this session itself. No match: say which sessions are running and stop; never start a new one.

## Compose the message

The receiver was not in this conversation and reads the message as information from another session, not as the user's instruction. A summary written by this session drops the nuance and the reasons behind the user's conclusions, and blends the user's intent with this session's interpretation. So the discussion travels verbatim, and the message only frames it.

1. Export the discussion of this topic with speaker labels: `transcript-excerpt --turns <n> --out tmp/ask/<slug>.md`, where `<n>` counts back to the user prompt where this topic began (the whole session when it is all one topic). It keeps user prompts and Claude's replies and drops tool traffic.
2. Write the message so it stands alone:
   - First line: who is asking (this session's name or project) and that the user asked for it.
   - The ask: what to consider or do, and where its result goes (a file, a plan item, a reply). Leave approvals to the user in that session; never ask it to do something the user has not approved there, and never route around a refusal this session got.
   - The excerpt's absolute path, with a note that `User:` lines are the user's own words and `Claude:` lines are this session's take, which the receiver is free to disagree with.
   - The user's load-bearing statements quoted exactly, never paraphrased. This session's own view, if worth sending, marked as this session's view.
   - What else is established, as pointers: file paths, doc sections, commit hashes, backlog items. Paths, never pasted file content (`@` attachments do not travel).
   - Whether to reply. A cloud session cannot reply or read local files; for it, paste the excerpt into the message instead of the path, and read its transcript for the answer.

Match the language the user is working in.

When the user's request already says what to send, send it. When it leaves the content to you, compose it from the conversation and send without a confirmation round, unless the message would commit the user to something (a decision, an approval, an outside contact): then show the draft first.

## After sending

Tell the user the session it went to and one line on what was asked, nothing more: the delivery state (in the inbox, unread, the receiver busy) is not reported, and the send is not checked again with ListAgents. A delivery notice that the session held or refused the message is the exception and is reported. Never predict or invent the receiver's answer; a reply arrives as a message in this session when it comes.
