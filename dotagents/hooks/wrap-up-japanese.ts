// PreToolUse on the desktop app's next-step box (mcp__ccd_turn__wrap_up, Claude only): its recap, question and buttons
// are a reply too (AGENTS.md Interaction, Language), so on a turn the user wrote in Japanese they are refused in
// English. A refusal rather than a Stop block as in reply-language.ts: the box is drawn once and cannot be corrected.
const input = await new Response(Bun.stdin.stream()).json().catch(() => ({}))
const ti = input.tool_input ?? {}
const fields: string[] = [ti.recap, ti.ask, ...(Array.isArray(ti.actions) ? ti.actions.map((a: any) => a?.label) : [])].filter((x): x is string => typeof x === 'string' && x !== '')
if (!fields.length || !input.transcript_path) process.exit(0)

const strip = (t: string) => t.replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '').replace(/https?:\S+|file:\S+/g, '').replace(/0x[0-9a-fA-F]+/g, '')
const count = (t: string) => {
  const s = strip(t)
  return { ja: (s.match(/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/gu) ?? []).length, latin: (s.match(/[A-Za-z]/g) ?? []).length }
}

let typed = ''
for (const line of (await Bun.file(input.transcript_path).text()).split('\n')) {
  if (!line) continue
  let e: any
  try { e = JSON.parse(line) } catch { continue }
  const content = e.message?.content
  if (e.type === 'user' && (typeof content === 'string' || (Array.isArray(content) && !content.some((c: any) => c.type === 'tool_result'))))
    typed = typeof content === 'string' ? content : content.map((c: any) => c.text ?? '').join(' ')
}
// a turn the user wrote in English is answered in English
if (!count(typed).ja && (typed.match(/[A-Za-z]{2,}/g) ?? []).length >= 3) process.exit(0)

// a field with no kana or kanji at all is English; a short label of Latin letters alone (a commit hash, "OK") passes
const english = fields.filter((f) => { const { ja, latin } = count(f); return !ja && latin >= 4 })
if (!english.length) process.exit(0)
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PreToolUse',
    permissionDecision: 'deny',
    permissionDecisionReason: `wrap-up-japanese: 次のステップ欄（recap、ask、ボタン）は返答なので日本語で書く: ${english.map((f) => `「${f.slice(0, 40)}」`).join(' ')}。 日本語にして同じ呼び出しをし直す。`,
  },
}))
