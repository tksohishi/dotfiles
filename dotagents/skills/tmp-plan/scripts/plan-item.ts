// Edit one item of a tmp-plan brief's frontmatter by its slug, never by a substring of its text.
// Usage:
//   bun plan-item.ts move <brief.md> <slug> <todo|done|blocked> "<new item text>"
//   bun plan-item.ts set  <brief.md> <slug> "<new item text>"
//   bun plan-item.ts drop <brief.md> <slug>
// The item text is the line's content without its `- "` and closing `"`; it starts with the item's own `{slug}`
// (`[P2] {slug} ...` in todo, `<hash> {slug} ...` in done, `{slug} ... — trigger: ...` in blocked). A todo item goes in at
// the end of its priority's run. The brief is copied to <dir>/.bak/ before every write.
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'

const [cmd, file, slug, a, b] = process.argv.slice(2)
const die = (why: string): never => {
  console.error(`plan-item: ${why}`)
  process.exit(1)
}
if (!cmd || !file || !slug) die('usage: move|set|drop <brief.md> <slug> ...')
const lists = ['done', 'todo', 'blocked'] as const
type List = (typeof lists)[number]

const lines = readFileSync(file as string, 'utf8').split('\n')
const end = () => lines.indexOf('---', 1)
if (lines[0] !== '---' || end() < 0) die(`${file} has no frontmatter`)

// an item line names its slug at its head: `- "[P0] {slug}`, `- "<hash> <hash> {slug}`, `- "{slug}`
const escaped = (slug as string).replace(/[.*+?^${}()|[\]\\]/g, (c) => `\\${c}`)
const head = new RegExp(`^ {2}- "(\\[P\\d\\] )?([0-9a-f]{7,40} )*\\{${escaped}\\}`)
const listOf = (i: number): List | undefined => {
  for (let j = i; j > 0; j--) {
    const m = /^(done|todo|blocked):/.exec(lines[j] as string)
    if (m) return m[1] as List
  }
  return undefined
}
const hits = lines.map((l, i) => (i < end() && head.test(l) ? i : -1)).filter((i) => i >= 0)
if (hits.length !== 1) die(`{${slug}} heads ${hits.length} item lines in ${file}; nothing written`)
const at = hits[0] as number

const lineOf = (body: string) => {
  if (!head.test(`  - "${body}`)) die(`the new text must start with {${slug}} (after an optional [Pn] or commit hashes)`)
  return `  - ${JSON.stringify(body)}`
}
const insertAt = (list: List, body: string) => {
  const start = lines.findIndex((l, i) => i < end() && (l === `${list}:` || l.startsWith(`${list}: `)))
  if (start < 0) die(`${file} has no ${list}: list`)
  lines[start] = `${list}:`
  const rank = /^\[P(\d)\]/.exec(body)?.[1]
  let i = start + 1
  while (i < end() && (lines[i] as string).startsWith('  - ')) {
    const r = /^ {2}- "\[P(\d)\]/.exec(lines[i] as string)?.[1]
    if (list === 'todo' && rank !== undefined && r !== undefined && Number(r) > Number(rank)) break
    i++
  }
  lines.splice(i, 0, lineOf(body))
}

if (cmd === 'drop') lines.splice(at, 1)
else if (cmd === 'set') lines[at] = lineOf(a ?? die('set needs the new item text'))
else if (cmd === 'move') {
  const to = a as List
  if (!lists.includes(to)) die(`move needs todo, done or blocked, not ${a}`)
  if (listOf(at) === to) die(`{${slug}} is already in ${to}; use set`)
  const body = b ?? die('move needs the new item text')
  lines.splice(at, 1)
  insertAt(to, body)
} else die(`unknown command ${cmd}`)

// a list left with no item reads `list: []`
for (const l of lists) {
  const i = lines.findIndex((x, n) => n < end() && x === `${l}:`)
  if (i >= 0 && !(lines[i + 1] ?? '').startsWith('  - ')) lines[i] = `${l}: []`
}
const bak = join(dirname(file as string), '.bak')
mkdirSync(bak, { recursive: true })
copyFileSync(file as string, join(bak, `${basename(file as string)}.${Date.now()}`))
writeFileSync(file as string, lines.join('\n'))
console.log(`plan-item: ${cmd} {${slug}} in ${file}`)
