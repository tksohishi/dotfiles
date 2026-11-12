// Stop hook (Claude only): block a final reply written in English on a turn the user wrote in Japanese (AGENTS.md
// Interaction, Language): the turn goes on until its last reply is in Japanese.
// Only the turn's last message is judged; the updates before it may be English. A draft for an outside party (a Telegram,
// Discord or mail reply) is written in a blockquote and is not counted, so a reply that is only the draft may be English.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
if (input.stop_hook_active || !input.transcript_path || input.hook_event_name !== 'Stop') process.exit(0)
const last = input.last_assistant_message
if (typeof last !== 'string' || !last) process.exit(0)

const strip = (t: string) => t.replace(/^>.*$/gm, '').replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '').replace(/https?:\S+|file:\S+/g, '').replace(/0x[0-9a-fA-F]+/g, '')
const count = (t: string) => {
  const s = strip(t)
  return { ja: (s.match(/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/gu) ?? []).length, latin: (s.match(/[A-Za-z]/g) ?? []).length }
}
const JA_SHARE_MIN = 0.1
// fewer letters than this and the share swings on a single word
const LETTERS_MIN = 20

const english = (t: string) => { const { ja, latin } = count(t); return ja + latin >= LETTERS_MIN && ja / (ja + latin) < JA_SHARE_MIN }

// each earlier turn's final reply, for the streak: the last assistant text before the next typed message
let typed = '', turnLast = ''
const finals: string[] = []
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result')))) {
    typed = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
    if (turnLast) finals.push(turnLast)
    turnLast = ''
  }
  if (e.type === 'assistant' && Array.isArray(content)) for (const c of content) if (c.type === 'text' && c.text) turnLast = c.text
}
// a turn the user wrote in English is answered in English
const asked = count(typed)
if (!asked.ja && (typed.match(/[A-Za-z]{2,}/g) ?? []).length >= 3) process.exit(0)
// so is a Japanese turn that asks for English outright
if (/英語で|英語だけ|英語のみ|英語の?[1一]文|英文|英訳|英語に(して|訳)|in English|English only|into English/i.test(typed)) process.exit(0)

if (!english(last)) process.exit(0)
let streak = 1
for (let i = finals.length - 1; i >= 0 && english(finals[i]!); i--) streak++
const reason = `reply-language: この返答は英語${streak > 1 ? `（${streak}返答連続）` : ''}。 ターンを終える前に、同じ内容を日本語で書き直す（結果、確かめていないこと、聞くこと）。 英語のままでよいのはコード、識別子、ログの引用だけ。`
console.log(JSON.stringify({ decision: 'block', reason, systemMessage: 'reply-language: 英語の返答、日本語で書き直します' }))
