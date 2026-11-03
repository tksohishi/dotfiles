export type Limit = { kind: string; percentUsed: number; resetsAt?: string }

export type Schedule = {
  wakeAt: number | null
  cronNext: number | null
  cronRecurring: boolean
  cronJobs: number
}

declare module 'claude-code' {
  interface PluginState {
    'desktop-status': { limits: Limit[]; schedule: Schedule }
  }
}
