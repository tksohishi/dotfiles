import { describe, expect, test, tier } from 'claude-code/testing'
import type { On } from 'claude-code'

tier('user')

const submit = (text = 'hi') =>
  ({ text, wait: false, origin: { kind: 'composer' } }) as const

/** Answers the world beneath: a settable context size, a passthrough submit, a log sink. */
function world(on: On, size: { tokens?: number }) {
  const logged: string[] = []
  const entered: (readonly string[] | undefined)[] = []
  on('session.usage', () => ({
    value: { context: { tokens: size.tokens, window: 1_000_000 }, rateLimits: [] },
  }))
  on('ui.log', ($, e) => {
    logged.push(e.text)
    return { value: undefined }
  })
  on('prompt.submit', ($, e) => {
    entered.push(e.context)
    return { text: e.text, context: e.context }
  })
  on('session.compact', () => ({
    messages: [{ role: 'user', text: 'summary', toolUses: [], toolResults: [] }],
  }))
  return { logged, entered }
}

describe('register', () => {
  test('below 300K nothing is logged or attached', async ($, on) => {
    const w = world(on, { tokens: 299_000 })
    await $.prompt.submit(submit())
    expect(w.logged).toEqual([])
    expect(w.entered).toEqual([undefined])
  })

  test('crossing 300K logs the size once and attaches the handoff context', async ($, on) => {
    const size = { tokens: 250_000 }
    const w = world(on, size)
    await $.prompt.submit(submit())
    size.tokens = 312_345
    await $.prompt.submit(submit())
    await $.prompt.submit(submit())
    expect(w.logged).toEqual(['Context is 312K tokens; every turn re-reads all of it.'])
    expect(w.entered.map(c => c?.length ?? 0)).toEqual([0, 1, 0])
    expect(w.entered[1]?.[0]).toContain("This session's context is 312K tokens")
  })

  test('each further 100K band fires again; the same band does not', async ($, on) => {
    const size = { tokens: 350_000 }
    const w = world(on, size)
    await $.prompt.submit(submit())
    size.tokens = 399_000
    await $.prompt.submit(submit())
    size.tokens = 401_000
    await $.prompt.submit(submit())
    expect(w.logged.length).toEqual(2)
  })

  test('a compaction resets the band so regrowing past 300K fires again', async ($, on) => {
    const size = { tokens: 350_000 }
    const w = world(on, size)
    await $.prompt.submit(submit())
    await $.session.compact({
      trigger: 'auto',
      messages: [{ role: 'user', text: 'long transcript', toolUses: [] }],
    })
    size.tokens = 360_000
    await $.prompt.submit(submit())
    expect(w.logged.length).toEqual(2)
  })

  test('a prompt from a plugin or peer is left alone', async ($, on) => {
    const w = world(on, { tokens: 900_000 })
    await $.prompt.submit({ text: 'x', wait: false, origin: { kind: 'plugin', plugin: 'p' } })
    expect(w.logged).toEqual([])
  })

  test('existing context entries are kept ahead of the nudge', async ($, on) => {
    const w = world(on, { tokens: 500_000 })
    await $.prompt.submit({ ...submit(), context: ['prior'] })
    expect(w.entered[0]?.[0]).toEqual('prior')
    expect(w.entered[0]?.length).toEqual(2)
  })

  test('no token figure yet: passes through', async ($, on) => {
    const w = world(on, {})
    await $.prompt.submit(submit())
    expect(w.logged).toEqual([])
  })
})
