#!/bin/bash
# Pre-hook on ExitPlanMode: plans large enough to be worth delegating must
# say, per implementation step, whether it runs [subagent] or [inline] (or
# opt out with a "Delegation: none — <reason>" line). The post-approval
# delegation nudge proved too soft — sessions acknowledged it and edited
# inline anyway — so the decision is forced into the plan text, where the
# user reviews it at approval time.
#
# Size gate: plans naming fewer than 3 distinct files pass untouched; simple
# work legitimately stays inline in the main (Fable) session.

input=$(cat)
plan=$(jq -r '.tool_input.plan // ""' <<<"$input")

[ -z "$plan" ] && exit 0

# Already annotated or explicitly opted out → pass.
if grep -qiE '\[(subagent|inline)\]|^[[:space:]]*delegation:' <<<"$plan"; then
    exit 0
fi

# Count distinct file-looking tokens (path.ext) in the plan.
file_count=$(grep -oE '[A-Za-z0-9_@/.-]+\.(tsx?|jsx?|mjs|css|scss|html|py|rs|go|rb|swift|kt|java|cpp|hpp|c|h|md|json|toml|yaml|yml|sh|bats|sql|vue|svelte)\b' <<<"$plan" | sort -u | wc -l | tr -d ' ')

[ "$file_count" -lt 3 ] && exit 0

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Plan names 3+ files but has no delegation annotations. Mark each implementation step [subagent] or [inline] (give inline steps a short reason: tight coupling, needs mid-course judgment, ...), or add a line \"Delegation: none — <reason>\" if the whole plan should stay in the main session. Self-contained steps default to [subagent]; frontend [subagent] steps must carry the plan'\''s design constraints in their prompts. Then re-submit ExitPlanMode."
  }
}'
exit 0
