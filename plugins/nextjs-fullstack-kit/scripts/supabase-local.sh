#!/bin/bash
# Start local Supabase and auto-configure .env.local with local keys.
# Requires: supabase CLI, Docker running.
# Usage: ./scripts/supabase-local.sh

set -euo pipefail

# --- Pre-flight checks ---

if ! command -v supabase &>/dev/null && ! npx supabase --version &>/dev/null 2>&1; then
  echo '{"error":"Supabase CLI not found. Install with: npm install -D supabase"}' >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo '{"error":"Docker is not running. Start Docker Desktop and try again."}' >&2
  exit 1
fi

# --- Check if already running ---

ALREADY_RUNNING=false
if supabase status >/dev/null 2>&1; then
  ALREADY_RUNNING=true
fi

# --- Start if needed ---

if [ "$ALREADY_RUNNING" = false ]; then
  echo "Starting local Supabase (first run may take 1-2 minutes to pull images)..." >&2

  if ! supabase start; then
    echo '{"error":"supabase start failed. Check Docker and port availability (54321-54326)."}' >&2
    exit 1
  fi
fi

# --- Parse status ---

STATUS_JSON=$(supabase status --output json 2>/dev/null || true)

if [ -z "$STATUS_JSON" ]; then
  echo '{"error":"Could not read supabase status. Is supabase running?"}' >&2
  exit 1
fi

if command -v jq &>/dev/null; then
  API_URL=$(echo "$STATUS_JSON" | jq -r '.API_URL // empty')
  ANON_KEY=$(echo "$STATUS_JSON" | jq -r '.ANON_KEY // empty')
  SERVICE_ROLE_KEY=$(echo "$STATUS_JSON" | jq -r '.SERVICE_ROLE_KEY // empty')
  DB_URL=$(echo "$STATUS_JSON" | jq -r '.DB_URL // empty')
  STUDIO_URL=$(echo "$STATUS_JSON" | jq -r '.STUDIO_URL // empty')
else
  API_URL=$(echo "$STATUS_JSON" | grep -o '"API_URL":"[^"]*"' | head -1 | cut -d'"' -f4)
  ANON_KEY=$(echo "$STATUS_JSON" | grep -o '"ANON_KEY":"[^"]*"' | head -1 | cut -d'"' -f4)
  SERVICE_ROLE_KEY=$(echo "$STATUS_JSON" | grep -o '"SERVICE_ROLE_KEY":"[^"]*"' | head -1 | cut -d'"' -f4)
  DB_URL=$(echo "$STATUS_JSON" | grep -o '"DB_URL":"[^"]*"' | head -1 | cut -d'"' -f4)
  STUDIO_URL=$(echo "$STATUS_JSON" | grep -o '"STUDIO_URL":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [ -z "$API_URL" ] || [ -z "$ANON_KEY" ]; then
  echo '{"error":"Failed to parse Supabase status output."}' >&2
  exit 1
fi

# --- Update .env.local ---

ENV_FILE=".env.local"
MARKER_START="# --- nsv:supabase-local:start ---"
MARKER_END="# --- nsv:supabase-local:end ---"

SUPABASE_BLOCK="${MARKER_START}
NEXT_PUBLIC_SUPABASE_URL=${API_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
SUPABASE_DB_URL=${DB_URL}
${MARKER_END}"

if [ -f "$ENV_FILE" ]; then
  # Remove old managed block if it exists
  if grep -q "$MARKER_START" "$ENV_FILE"; then
    # Delete everything between markers (inclusive)
    sed -i.bak "/${MARKER_START}/,/${MARKER_END}/d" "$ENV_FILE"
    rm -f "${ENV_FILE}.bak"
  fi
  # Append new block
  echo "" >> "$ENV_FILE"
  echo "$SUPABASE_BLOCK" >> "$ENV_FILE"
elif [ -f ".env.example" ]; then
  # Create from example and append
  cp .env.example "$ENV_FILE"
  echo "" >> "$ENV_FILE"
  echo "$SUPABASE_BLOCK" >> "$ENV_FILE"
else
  # Create fresh
  echo "$SUPABASE_BLOCK" > "$ENV_FILE"
fi

# --- Output JSON for agent consumption ---

echo "{\"apiUrl\":\"${API_URL}\",\"anonKey\":\"${ANON_KEY}\",\"serviceRoleKey\":\"${SERVICE_ROLE_KEY}\",\"dbUrl\":\"${DB_URL}\",\"studioUrl\":\"${STUDIO_URL}\",\"status\":\"running\",\"alreadyRunning\":${ALREADY_RUNNING}}"
