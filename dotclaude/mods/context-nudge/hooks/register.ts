import type { On } from 'claude-code'

/** Tokens per band; the nudge fires on entering a band at or past FIRST_BAND. */
export const BAND = 100_000
export const FIRST_BAND = 3

/**
 * The mod's one piece of state: the highest band the session has been seen
 * in. Falls with the context (a compaction), so regrowing past 300K fires
 * again; module state is per session, as the module loads per session.
 */
let lastBand = 0

export function contextOf(k: number): string {
  return (
    `This session's context is ${k}K tokens, and every request re-reads all of it. ` +
    'Finish the current request first. At the next natural task boundary, tell the user ' +
    'the size once and offer /handoff into a fresh session. If the user says they are ' +
    'stepping away and coming back within a few hours, suggest /keepalive instead so the ' +
    'cache does not expire; if they are done with this thread for the day, the handoff is ' +
    'the better choice.'
  )
}

export function register(on: On) {
  on('prompt.submit', async ($, e, next) => {
    if (e.origin.kind !== 'composer') return next(e)

    const tokens = (await $.session.usage()).context.tokens
    if (tokens === undefined) return next(e)

    const band = Math.floor(tokens / BAND)
    const fired = band >= FIRST_BAND && band > lastBand
    lastBand = band
    if (!fired) return next(e)

    const k = Math.floor(tokens / 1000)
    $.ui.log(`Context is ${k}K tokens; every turn re-reads all of it.`)
    return next({ ...e, context: [...(e.context ?? []), contextOf(k)] })
  })

  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    if (!e.agentId && result.messages) lastBand = 0
    return result
  })
}
