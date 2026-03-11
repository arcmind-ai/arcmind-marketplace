#!/bin/bash
# Stop the dev server started by dev-server.sh.
# Cleans up PID file and worktree-isolated metadata.
# Usage: ./scripts/dev-server-stop.sh

set -euo pipefail

if [ -f .dev-server.pid ]; then
  PID="$(cat .dev-server.pid)"
  kill -- "$PID" 2>/dev/null || true
  rm -f .dev-server.pid
  # Clean up worktree metadata files
  for meta in .logs/*/server-meta.json; do
    [ -f "$meta" ] || continue
    META_PID=$(jq -r '.pid // ""' "$meta" 2>/dev/null || echo "")
    if [ "$META_PID" = "$PID" ]; then
      rm -f "$meta"
    fi
  done
  echo "Dev server stopped (PID $PID)."
else
  echo "No dev server PID file found."
fi
