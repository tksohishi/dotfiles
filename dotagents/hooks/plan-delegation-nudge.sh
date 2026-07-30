#!/bin/bash
# Post-hook on ExitPlanMode: when a plan is approved, inject a reminder to
# delegate self-contained plan steps to subagents instead of editing inline.
# PostToolUse fires only on success, so a rejected plan never triggers this.
#
# Soft enforcement: the trigger is deterministic (every plan approval), the
# effect is a judgment nudge placed next to the tool result — where the
# inline-edit inertia starts — rather than an AGENTS.md bullet far back in
# context.

cat > /dev/null  # consume stdin; the payload isn't needed

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "Plan approved. Before editing inline: delegate self-contained plan steps to subagents, keeping only integration, verification, and steps needing mid-course judgment in the main loop. Small plans (a handful of edits in one area) stay inline."
  }
}'
exit 0
