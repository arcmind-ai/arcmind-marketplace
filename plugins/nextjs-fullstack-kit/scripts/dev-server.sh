#!/bin/bash
# Start dev server on a random port and write metadata for agent use.
# Supports ephemeral per-worktree log isolation.
# Usage: ./scripts/dev-server.sh

set -euo pipefail

PORT=$((3001 + RANDOM % 99))

# Check if local Supabase is running (warn only — don't block cloud setups)
if [ -f "supabase/config.toml" ]; then
  if command -v supabase &>/dev/null; then
    if ! supabase status >/dev/null 2>&1; then
      echo '{"warning":"Local Supabase is not running. Start it with: ./scripts/supabase-local.sh"}' >&2
    fi
  fi
fi

# Ephemeral log isolation: each worktree gets its own log directory.
# Detect if running inside a git worktree (path differs from main repo).
MAIN_WORKTREE=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')
CURRENT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

if [ -n "$MAIN_WORKTREE" ] && [ "$CURRENT_DIR" != "$MAIN_WORKTREE" ]; then
  # Running in a worktree — use isolated log dir
  WORKTREE_ID=$(basename "$CURRENT_DIR")
  LOG_DIR=".logs/$WORKTREE_ID"
else
  # Main worktree — default behavior
  WORKTREE_ID="main"
  LOG_DIR=".logs"
fi

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/app.ndjson"

npm run dev -- -p $PORT > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Write metadata as JSON for agent consumption
META_FILE="$LOG_DIR/server-meta.json"
echo "{\"port\":$PORT,\"pid\":$SERVER_PID,\"logFile\":\"$LOG_FILE\",\"worktreeId\":\"$WORKTREE_ID\",\"logDir\":\"$LOG_DIR\"}" > "$META_FILE"

echo $SERVER_PID > .dev-server.pid
echo "{\"port\":$PORT,\"pid\":$SERVER_PID,\"logFile\":\"$LOG_FILE\",\"worktreeId\":\"$WORKTREE_ID\",\"logDir\":\"$LOG_DIR\"}"

# Wait for the server to be ready (max 30s)
SERVER_READY=false
for i in $(seq 1 30); do
  if curl -s http://localhost:$PORT > /dev/null 2>&1; then
    SERVER_READY=true
    break
  fi
  sleep 1
done

if [ "$SERVER_READY" = false ]; then
  echo "{\"error\":\"Dev server failed to start on port $PORT after 30s\"}" >&2
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi
