import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Schedule } from '../types'

const monitors = atom({ plugin: 'desktop-status', key: 'monitors' } as const, [])
const schedule = atom({ plugin: 'desktop-status', key: 'schedule' } as const, {
  wakeAt: null,
  cronNext: null,
  cronRecurring: false,
  cronJobs: 0,
})

const hhmm = (epoch: number) => {
  const d = new Date(epoch * 1000)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

// Mirrors the cron section of dotclaude/statusline.sh, which reads the files
// hooks/cron-state.sh writes: "fire recurring created offset minutes...".
const nextCronFire = (line: string, now: number) => {
  const [fireS, recurring, createdS, offsetS, ...minuteS] = line.trim().split(/\s+/)
  const fire = Number(fireS)
  if (recurring !== 'true') return fire > now ? { next: fire, recurring: false } : null
  if (Number(createdS) + 7 * 86400 <= now) return null
  if (fire > now) return { next: fire, recurring: true }
  const minutes = minuteS.map(Number)
  const first = minutes[0]
  if (first === undefined) return { next: null, recurring: true }
  const offset = Number(offsetS)
  const base = now - offset
  const inHour = base % 3600
  const m = minutes.find(x => x * 60 > inHour) ?? first + 60
  return { next: base - inHour + m * 60 + offset, recurring: true }
}

async function refresh($: EngineInterface) {
  const home = await $.env.get('HOME')
  const id = await $.session.id()
  const now = Math.floor((await $.clock.now()) / 1000)
  const next: Schedule = { wakeAt: null, cronNext: null, cronRecurring: false, cronJobs: 0 }

  const wakeFile = `${home}/.claude/state/wakeups/${id}`
  if (await $.fs.exists(wakeFile)) {
    const at = Number((await $.fs.read(wakeFile)).trim())
    if (at > now) next.wakeAt = at
  }

  const cronDir = `${home}/.claude/state/crons/${id}`
  if (await $.fs.exists(cronDir)) {
    for (const entry of await $.fs.list(cronDir)) {
      if (entry.kind !== 'file') continue
      const fire = nextCronFire(await $.fs.read(`${cronDir}/${entry.name}`), now)
      if (!fire) continue
      next.cronJobs += 1
      if (fire.next !== null && (next.cronNext === null || fire.next < next.cronNext)) {
        next.cronNext = fire.next
        next.cronRecurring = fire.recurring
      }
    }
  }

  await update($, schedule, () => next)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    $.clock.every(30_000, () => void refresh($))
    return result
  })

  on('classic.Stop', async ($, e, next) => {
    const running = (e.background_tasks ?? []).filter(t => t.type === 'monitor').map(t => t.description)
    await update($, monitors, () => running)
    await refresh($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.surface !== 'desktop' || e.props.hasSurvey) return next(e)

    const parts: string[] = []
    const s = await read($, schedule)
    if (s.wakeAt) parts.push(`⏰ ${hhmm(s.wakeAt)}`)
    if (s.cronJobs > 0) {
      let cron = `🕐 ${s.cronNext ? hhmm(s.cronNext) : '↻'}`
      if (s.cronNext && s.cronRecurring) cron += ' ↻'
      if (s.cronJobs > 1) cron += ` +${s.cronJobs - 1}`
      parts.push(cron)
    }
    const watching = await read($, monitors)
    const firstMonitor = watching[0]
    if (firstMonitor !== undefined) {
      parts.push(`👁 ${firstMonitor}${watching.length > 1 ? ` +${watching.length - 1}` : ''}`)
    }
    if (parts.length === 0) return next(e)

    const { Text } = $.ui.resolve(e)
    return <Text dimColor>{parts.join('  ·  ')}</Text>
  })
}
