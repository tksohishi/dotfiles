// UserPromptSubmit hook (Claude only): note to the agent a time the previous reply wrote in UTC (`19:11 UTC`,
// `17:20:59Z`), which the global AGENTS.md rules out: times are in the user's local zone, with no UTC beside them unless
// the user asked for UTC. Code spans, fenced code and URLs are skipped, since a quoted log line keeps its own clock.
// Read from the transcript at prompt time, as ja-spacing.ts does. The note goes to the agent only.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
if (!input.transcript_path) process.exit(0)

// the assistant text after the last message the user typed before this prompt (tool results also arrive as "user")
const replies: string[][] = []
let promptsSince = 1
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result')))) promptsSince++
  if (e.type === 'assistant' && Array.isArray(content)) for (const c of content) if (c.type === 'text') { if (promptsSince) { replies.push([]); promptsSince = 0 } replies.at(-1)!.push(c.text) }
}
if (promptsSince > 1 || !replies.length) process.exit(0)

const text = replies.at(-1)!.join('\n\n').replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '``').replace(/https?:\/\/[^\s)]+/g, 'URL')
const hits = [...text.matchAll(/\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?\s*(?:UTC|GMT|Z\b)/g)].map((m) => text.slice(Math.max(0, m.index! - 10), m.index! + m[0].length + 6).replace(/\n/g, ' '))
if (hits.length) {
  const note = `utc-time: 前回の返答に UTC の時刻が${hits.length}件（${hits.slice(0, 3).map((h) => `「${h}」`).join(' ')}）。 時刻はユーザーのローカル時間（ET）だけで書き、UTC は併記しない。 ユーザーが UTC を指定したときだけ UTC で書く。 変換は date で行う。 前回の返答は直さない。`
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: note } }))
}
