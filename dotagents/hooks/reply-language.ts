// Stop and PreToolUse(AskUserQuestion) hook (Claude only), for text the user reads on a turn they wrote in Japanese
// (AGENTS.md Interaction, Language).
// Stop: block a final reply written in English; the turn goes on until its last reply is in Japanese. Only the turn's
// last message is judged; the updates before it may be English. A draft for an outside party (a Telegram, Discord or
// mail reply) is written in a blockquote and is not counted, so a reply that is only the draft may be English.
// AskUserQuestion: the dialog can only be answered well when the text right before it says what the problem is and
// what has to be decided, in Japanese, and the question itself carries only the point to decide. Deny a question with
// no such text since the last tool result, with that text in English, or whose own text is too long.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
const event = input.hook_event_name
const asking = event === 'PreToolUse' && input.tool_name === 'AskUserQuestion'
if (!input.transcript_path || !(asking || (event === 'Stop' && !input.stop_hook_active))) process.exit(0)

const strip = (t: string) => t.replace(/^>.*$/gm, '').replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '').replace(/https?:\S+|file:\S+/g, '').replace(/0x[0-9a-fA-F]+/g, '')
const count = (t: string) => {
  const s = strip(t)
  return { ja: (s.match(/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/gu) ?? []).length, latin: (s.match(/[A-Za-z]/g) ?? []).length }
}
const JA_SHARE_MIN = 0.1
// fewer letters than this and the share swings on a single word
const LETTERS_MIN = 20
// an explanation shorter than this cannot say both the problem and the decision
const PREAMBLE_MIN = 60
const QUESTION_MAX = 60

const english = (t: string) => { const { ja, latin } = count(t); return ja + latin >= LETTERS_MIN && ja / (ja + latin) < JA_SHARE_MIN }

// each earlier turn's final reply, for the streak: the last assistant text before the next typed message.
// `step` is the text written since the last typed message or tool result: what sits right above a question dialog
let typed = '', turnLast = ''
let step: string[] = []
const finals: string[] = []
// an interactive session writes the transcript in batches, so at PreToolUse the text before the call is usually not
// in the file yet. The checks on that text run only when this call's own tool_use is already there (headless runs)
const transcript = await Bun.file(input.transcript_path).text()
const textLanded = !!input.tool_use_id && transcript.includes(`"id":"${input.tool_use_id}"`)
for (const line of transcript.split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && Array.isArray(content) && content.some((c: any) => c.type === 'tool_result')) step = []
  else if (e.type === 'user' && (typeof content === 'string' || Array.isArray(content))) {
    typed = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
    if (turnLast) finals.push(turnLast)
    turnLast = ''
    step = []
  }
  if (e.type === 'assistant' && Array.isArray(content)) for (const c of content) if (c.type === 'text' && c.text) { turnLast = c.text; step.push(c.text) }
}
// a turn the user wrote in English is answered in English
const asked = count(typed)
const englishTurn = (!asked.ja && (typed.match(/[A-Za-z]{2,}/g) ?? []).length >= 3)
  // so is a Japanese turn that asks for English outright
  || /英語で|英語だけ|英語のみ|英語の?[1一]文|英文|英訳|英語に(して|訳)|in English|English only|into English/i.test(typed)

if (asking) {
  const problems: string[] = []
  const pre = step.join('\n\n')
  const { ja, latin } = count(pre)
  if (textLanded && ja + latin < PREAMBLE_MIN) problems.push('質問の前に説明がない。 何が問題になっていて、何を決めてもらう必要があるかを、質問の直前に本文で書く')
  else if (textLanded && !englishTurn && english(pre)) problems.push('質問の前の説明が英語。 日本語で書き直す')
  const long = (input.tool_input?.questions ?? []).map((q: any) => String(q.question ?? '')).filter((q: string) => q.length > QUESTION_MAX)
  if (long.length) problems.push(`質問文が長い（${long.map((q: string) => q.length).join('、')}字、上限${QUESTION_MAX}字）。 経緯や理由は質問の前の本文に移し、質問には決めることだけを書く`)
  if (!problems.length) process.exit(0)
  const reason = `reply-language: ${problems.join(' ')}。 そのあとで質問し直す。`
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason } }))
  process.exit(0)
}

const last = input.last_assistant_message
if (typeof last !== 'string' || !last || englishTurn || !english(last)) process.exit(0)
let streak = 1
for (let i = finals.length - 1; i >= 0 && english(finals[i]!); i--) streak++
const reason = `reply-language: この返答は英語${streak > 1 ? `（${streak}返答連続）` : ''}。 ターンを終える前に、同じ内容を日本語で書き直す（結果、確かめていないこと、聞くこと）。 英語のままでよいのはコード、識別子、ログの引用だけ。`
console.log(JSON.stringify({ decision: 'block', reason, systemMessage: 'reply-language: 英語の返答、日本語で書き直します' }))
