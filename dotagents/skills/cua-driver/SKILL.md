---
name: cua-driver
description: Drive a native macOS app via the cua-driver CLI. ONLY use when the user explicitly invokes /cua-driver or names cua-driver in their request — never choose GUI automation on your own initiative, even when a GUI action would accomplish the task, because it steals mouse/keyboard focus from the user. If GUI automation seems like the right approach, propose it and wait for approval instead.
---

# cua-driver (gated wrapper)

This shadows the skill shipped inside CuaDriver.app so the trigger is
explicit-invocation-only. The full operating manual lives in the app
bundle and must be followed as-is:

Read `/Applications/CuaDriver.app/Contents/Resources/Skills/cua-driver/SKILL.md`
now and follow it (it references sibling docs like RECORDING.md and
WEB_APPS.md in the same directory). Everything there applies unchanged,
including the no-foreground contract and the snapshot-before-action loop.
