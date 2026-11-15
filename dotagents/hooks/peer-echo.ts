// Stop hook (Claude only): the user reads every session, so what a peer session found is shown once, in that session's
// own reply; the session it reports to does not retell it. Text this session sends is not checked: the sender is where
// the finding is shown. Two measures, since peers often write to each other in English while the reply to the user is
// Japanese:
// - shingles: 4-character pieces of the reply, for a retelling in the same language
// - anchors: numbers, times, hashes and identifiers, which survive translation. A peer's anchor that this turn's own
//   tool results also show counts as this session's own finding, so a report of work the peer asked for passes.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
if (input.hook_event_name !== 'Stop' || input.stop_hook_active || !input.transcript_path) process.exit(0)
const last = input.last_assistant_message
if (typeof last !== 'string' || !last) process.exit(0)

const N = 4
// in degen's records, a same-language retelling scores 0.3 and up on shingles
const SHINGLE_SHARE_MAX = 0.3
// a translated retelling scores 0.6 to 0.9 on anchors; a report of the session's own work stays under 0.3
const ANCHOR_SHARE_MAX = 0.5
// a short reply that quotes one figure or a name is fine
const SHINGLES_MIN = 80
const ANCHORS_MIN = 6

const unwrap = (t: string) => t.replace(/<\/?cross-session-message[^>]*>/g, '')
const shingles = (t: string) => {
  const s = unwrap(t).replace(/[\s*#|>`_\-、。・：:（）()「」]/g, '')
  const out = new Set<string>()
  // hiragana-only shingles are inflections and particles every Japanese text shares
  for (let i = 0; i + N <= s.length; i++) { const g = s.slice(i, i + N); if (!/^[\p{Script=Hiragana}ー]+$/u.test(g)) out.add(g) }
  return out
}
const anchors = (t: string) => new Set((unwrap(t).match(/0x[0-9a-fA-F]+|\d+(?:[.:,/]\d+)*|[A-Za-z][A-Za-z0-9_.\-]{3,}/g) ?? []).map(x => x.toLowerCase()))

const peer = /^\s*(<cross-session-message|Another Claude session sent a message)/
let incoming = '', own = ''
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result')))) {
    const text = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
    incoming = peer.test(text) ? text : ''
    own = ''
  }
  if (e.type === 'user' && Array.isArray(content)) for (const c of content) {
    if (c.type === 'tool_result') own += ' ' + (typeof c.content === 'string' ? c.content : JSON.stringify(c.content))
  }
}
if (!incoming) process.exit(0)

const share = (reply: Set<string>, src: Set<string>, skip = new Set<string>()) => {
  let n = 0
  for (const x of reply) if (src.has(x) && !skip.has(x)) n++
  return n / reply.size
}
const rs = shingles(last), ra = anchors(last)
const echoes = (src: string, skip?: Set<string>) =>
  (rs.size >= SHINGLES_MIN && share(rs, shingles(src)) > SHINGLE_SHARE_MAX) || (ra.size >= ANCHORS_MIN && share(ra, anchors(src), skip) > ANCHOR_SHARE_MAX)

if (!echoes(incoming, anchors(own))) process.exit(0)
const reason = 'peer-echo: この返答の大半が、届いたメッセージの繰り返し（訳しただけのものを含む）。 ユーザーは相手のセッションで同じ内容を読んでいる。 書き直す: 誰から何が届いたかを1行、そのあとはこのセッションの差分だけ（賛成か反論とその根拠、答えに足りない点、次にすること）。 差分がなければ1行で終える。'
console.log(JSON.stringify({ decision: 'block', reason, systemMessage: 'peer-echo: 相手のセッションと重なる返答、差分だけに書き直します' }))
