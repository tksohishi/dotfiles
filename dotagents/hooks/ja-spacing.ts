// UserPromptSubmit hook (Claude only): note to the agent the previous reply's breaks of the 日本語の注意点 spacing
// rules in AGENTS.md: a space between a number, amount or sign and Japanese (`約1.5 ETH`, never `約 1.5 ETH`; a Latin
// word beside Japanese is free), and no half-width space after a 。 that a sentence follows on the same line.
// A backticked span keeps a space on each side, so code spans are blanked to `` before the scan; fenced code, URLs and
// table rows are skipped. It reads the transcript at prompt time rather than handing a note over from a Stop hook,
// which lost notes when the Stop did not run. The note goes to the agent only.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
if (!input.transcript_path) process.exit(0)

// the replies, one per message the user typed (tool results also arrive as "user"): the assistant text after it. The
// prompt being submitted may or may not be in the file yet, so the last non-empty reply is the one noted, and one that
// two typed messages already follow was noted at the previous prompt
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

const ja = '\\p{Script=Hiragana}\\p{Script=Katakana}\\p{Script=Han}ー'
const ascii = '0-9$%+\\-' // a number, amount or sign; never `.`: the only period this hook judges is 。 (a list marker `1. ` keeps its space)
function check(reply: string[]): { bad: string[]; noSpace: string[] } {
  const bad: string[] = [], noSpace: string[] = []
  const text = reply.join('\n\n').replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '``').replace(/https?:\/\/[^\s)]+/g, 'URL') // stops at a markdown link's closing bracket, or it swallows the sentence after it
    .replace(/「[^「」\n]*」/g, '「」') // a quoted slip is a literal, not the reply's own spacing
  for (const raw of text.split('\n')) {
    if (/^\s*\|/.test(raw)) continue // a table row: cells are padded with spaces on purpose
    const line = raw.replace(/^\s*[-*+]\s+/, '') // a bullet marker keeps its space
      .replace(/ [x+=] /g, '·') // an operator standing alone in a formula keeps its spaces (コレクション数 x 頻度, 100 ms + 署名)
    for (const m of line.matchAll(new RegExp(`(?:[${ja}][ \\u3000]+[${ascii}])|(?:[${ascii}][ \\u3000]+[${ja}])`, 'gu'))) {
      const i = m.index!
      const before = line.slice(0, i)
      if (/``\s*$/.test(before) || /^\s*``/.test(line.slice(i + m[0].length - 1))) continue // the space beside a code span
      bad.push(line.slice(Math.max(0, i - 12), i + m[0].length + 12))
    }
    // a half-width space after 。 (a break opportunity for the terminal's word wrap); a closing bracket or quote may follow first.
    // Each hit is shown as it was and as it should be: "not at the end of a line" was misread as "only at the end of a line"
    for (const m of line.matchAll(/。(?![ \n」』）)])/g)) if (m.index! + 1 < line.length) {
      const a = line.slice(Math.max(0, m.index! - 8), m.index! + 1), b = line.slice(m.index! + 1, m.index! + 7)
      noSpace.push(`「${a}${b}」 → 「${a} ${b}」`)
    }
  }
  return { bad, noSpace }
}

const { bad, noSpace } = check(replies.at(-1)!)
if (bad.length || noSpace.length) {
  // the count and the streak lead: a short list of quotes reads as a nit when a reply carries a hundred
  let streak = 0
  for (let i = replies.length - 1; i >= 0; i--) { const r = check(replies[i]!); if (!r.bad.length && !r.noSpace.length) break; streak++ }
  // the note is in the reply's language and leads with the pattern to produce, not the reply's slips: a quoted slip is copied into the next reply
  const parts = []
  if (bad.length) parts.push(`数字・金額・記号の直後に日本語が来るときは空白を入れない: 「3件」「約1.5 ETH」「1と2を」「10分行」「12:54に」。 空白が残るのは Latin 語の前後とバッククォートの両側だけ。 前回の空白: ${bad.slice(0, 3).map((b) => `「${b}」`).join(' ')}${bad.length > 3 ? `（他${bad.length - 3}件）` : ''}`)
  if (noSpace.length) parts.push(`同じ行で 。 の後に文が続くときは 。 の直後に半角空白を1つ（行末の 。 には何も付けない）。 前回: ${noSpace.slice(0, 2).join('、')}${noSpace.length > 2 ? `（他${noSpace.length - 2}件）` : ''}`)
  // never a block: a block costs a rewrite of the whole reply, and the user has refused block mode; do not propose it
  const note = `ja-spacing: 前回の返答に${bad.length + noSpace.length}件${streak > 1 ? `（${streak}返答連続）` : ''}。 ${parts.join(' ')} 送る前に、返答の数字を1つずつ見て、直後が空白なら次がアルファベットかバッククォートでない限り空白を消す。 前回の返答は直さない。`
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: note } }))
}
