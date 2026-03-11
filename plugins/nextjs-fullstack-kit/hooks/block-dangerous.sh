#!/bin/bash
# PreToolUse hook for Bash commands. Blocks dangerous operations.
# Returns JSON with permissionDecision: "deny" to block, or exits 0 to allow.
# Input: JSON on stdin with tool_input.command

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Block dropping tables
if echo "$CMD" | grep -qi "drop table"; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "DROP TABLE detected. Use Supabase migrations instead."}}'
  exit 0
fi

# Block deleting migration files
if echo "$CMD" | grep -qi "rm.*migrations"; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Do not delete migration files. Create a new migration to undo changes."}}'
  exit 0
fi

# Block force push
if echo "$CMD" | grep -qiE "git push.*(--force|-f)"; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Force push not allowed. Use regular push."}}'
  exit 0
fi

# Warn on supabase db push without dry-run (production migration)
if echo "$CMD" | grep -qi "supabase db push" && ! echo "$CMD" | grep -qi "\-\-dry-run"; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: "supabase db push will modify production database. Consider running with --dry-run first."}}'
  exit 0
fi

exit 0
