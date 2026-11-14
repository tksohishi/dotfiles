// Stop and PreToolUse(AskUserQuestion) hook (Claude only), for text the user reads on a turn they wrote in Japanese
// (AGENTS.md Interaction, Language).
// Stop: block a final reply written in English; the turn goes on until its last reply is in Japanese. Only the turn's
// last message is judged; the updates before it may be English. A draft for an outside party (a Telegram, Discord or
// mail reply) is written in a blockquote and is not counted, so a reply that is only the draft may be English.
// AskUserQuestion: the question carries only the point to decide; the problem and the choice go in the reply before
// it. PreToolUse denies a question whose own text is too long. The text before the dialog is not checked: the
// transcript does not reliably hold it (at PreToolUse an interactive session has not written it yet, and some text
// before an answered question was never written at all).
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
const event = input.hook_event_name
const asking = event === 'PreToolUse' && input.tool_name === 'AskUserQuestion'
if (asking) {
  const long = (input.tool_input?.questions ?? []).map((q: any) => String(q.question ?? '')).filter((q: string) => q.length > 60)
  if (!long.length) process.exit(0)
  const reason = `reply-language: 質問文が長い（${long.map((q: string) => q.length).join('、')}字、上限60字）。 経緯や理由は質問の前の本文に移し、質問には決めることだけを書いて質問し直す。`
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: reason } }))
  process.exit(0)
}
if (!input.transcript_path || event !== 'Stop' || input.stop_hook_active) process.exit(0)

const strip = (t: string) => t.replace(/^>.*$/gm, '').replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '').replace(/https?:\S+|file:\S+/g, '').replace(/0x[0-9a-fA-F]+/g, '')
const count = (t: string) => {
  const s = strip(t)
  return { ja: (s.match(/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/gu) ?? []).length, latin: (s.match(/[A-Za-z]/g) ?? []).length }
}
const JA_SHARE_MIN = 0.1
// fewer letters than this and the share swings on a single word
const LETTERS_MIN = 20

const english = (t: string) => { const { ja, latin } = count(t); return ja + latin >= LETTERS_MIN && ja / (ja + latin) < JA_SHARE_MIN }
// a turn the user wrote in English is answered in English; so is a Japanese turn that asks for English outright
const englishAsk = (typed: string) => (!count(typed).ja && (typed.match(/[A-Za-z]{2,}/g) ?? []).length >= 3)
  || /英語で|英語だけ|英語のみ|英語の?[1一]文|英文|英訳|英語に(して|訳)|in English|English only|into English/i.test(typed)

// each earlier turn's final reply, for the streak: the last assistant text before the next typed message
let typed = '', turnLast = ''
const finals: string[] = []
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result')))) {
    const text = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
    // a peer session's message or a background task notice starts a turn too, but its language is not the user's
    if (!e.isMeta && !/^\s*(<task-notification>|<cross-session-message|Another Claude session sent a message)/.test(text)) typed = text
    if (turnLast) finals.push(turnLast)
    turnLast = ''
  }
  if (e.type === 'assistant' && Array.isArray(content)) for (const c of content) if (c.type === 'text' && c.text) turnLast = c.text
}

const last = input.last_assistant_message
if (typeof last !== 'string' || !last || englishAsk(typed) || !english(last)) process.exit(0)
let streak = 1
for (let i = finals.length - 1; i >= 0 && english(finals[i]!); i--) streak++
const reason = `reply-language: この返答は英語${streak > 1 ? `（${streak}返答連続）` : ''}。 ターンを終える前に、同じ内容を日本語で書き直す（結果、確かめていないこと、聞くこと）。 英語のままでよいのはコード、識別子、ログの引用だけ。`
console.log(JSON.stringify({ decision: 'block', reason, systemMessage: 'reply-language: 英語の返答、日本語で書き直します' }))
