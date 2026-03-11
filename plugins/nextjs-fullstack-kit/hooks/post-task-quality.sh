#!/bin/bash
# Stop hook. Runs a quick quality check after Claude finishes a task.
# Reminds the agent to check for common issues.

# Check for uncommitted changes
if git status --porcelain 2>/dev/null | grep -q .; then
  echo "Reminder: There are uncommitted changes. Consider committing or stashing." >&2
fi

exit 0
