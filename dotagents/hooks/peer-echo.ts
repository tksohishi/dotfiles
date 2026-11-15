// Stop hook (Claude only): the user reads every session, so text another session already showed them, or text this
// turn already sent to one, is not written again in the final reply. Blocks a final reply whose 4-character shingles
// mostly come from the peer message that started the turn or from a SendMessage body sent this turn.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
if (input.hook_event_name !== 'Stop' || input.stop_hook_active || !input.transcript_path) process.exit(0)
const last = input.last_assistant_message
if (typeof last !== 'string' || !last) process.exit(0)

const N = 4
// in degen's records, replies that retell a peer's answer score 0.3 and up
const ECHO_SHARE_MAX = 0.3
// a short reply that quotes one figure or a name is fine
const SHINGLES_MIN = 80

const shingles = (t: string) => {
  const s = t.replace(/<\/?cross-session-message[^>]*>/g, '').replace(/[\s*#|>`_\-、。・：:（）()「」]/g, '')
  const out = new Set<string>()
  // hiragana-only shingles are inflections and particles every Japanese text shares
  for (let i = 0; i + N <= s.length; i++) { const g = s.slice(i, i + N); if (!/^[\p{Script=Hiragana}ー]+$/u.test(g)) out.add(g) }
  return out
}

const peer = /^\s*(<cross-session-message|Another Claude session sent a message)/
let incoming = '', sent: string[] = []
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result')))) {
    const text = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
    incoming = peer.test(text) ? text : ''
    sent = []
  }
  if (e.type === 'assistant' && Array.isArray(content)) for (const c of content) {
    if (c.type === 'tool_use' && c.name === 'SendMessage' && typeof c.input?.message === 'string') sent.push(c.input.message)
  }
}
if (!incoming && !sent.length) process.exit(0)

const reply = shingles(last)
if (reply.size < SHINGLES_MIN) process.exit(0)
const share = (src: string) => { const s = shingles(src); let n = 0; for (const x of reply) if (s.has(x)) n++; return n / reply.size }
const fromIncoming = incoming ? share(incoming) : 0
const fromSent = sent.length ? share(sent.join('\n')) : 0
if (Math.max(fromIncoming, fromSent) <= ECHO_SHARE_MAX) process.exit(0)

const pct = (x: number) => `${Math.round(x * 100)}%`
const reason = fromIncoming >= fromSent
  ? `peer-echo: この返答の${pct(fromIncoming)}が、届いたメッセージの繰り返し。 ユーザーは相手のセッションで同じ内容を読んでいる。 書き直す: 誰から何が届いたかを1行、そのあとはこのセッションの差分だけ（賛成か反論とその根拠、答えに足りない点、次にすること）。`
  : `peer-echo: この返答の${pct(fromSent)}が、このターンで相手に送った本文の繰り返し。 ユーザーは相手のセッションでも読む。 書き直す: どのセッションに何を送ったかを1行、そのあとは送った本文にない内容だけ。`
console.log(JSON.stringify({ decision: 'block', reason, systemMessage: 'peer-echo: 相手のセッションと重なる返答、差分だけに書き直します' }))
