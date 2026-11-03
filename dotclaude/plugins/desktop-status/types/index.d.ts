export type Schedule = {
  wakeAt: number | null
  cronNext: number | null
  cronRecurring: boolean
  cronJobs: number
}

declare module 'claude-code' {
  interface PluginState {
    'desktop-status': { monitors: string[]; schedule: Schedule }
  }
}
