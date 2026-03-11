#!/bin/bash
# Stop local Supabase.
# Usage: ./scripts/supabase-local-stop.sh [--reset]
#   --reset  Also clears local database volumes (fresh start next time)

set -euo pipefail

if ! command -v supabase &>/dev/null; then
  echo '{"error":"Supabase CLI not found."}' >&2
  exit 1
fi

RESET=false
if [ "${1:-}" = "--reset" ]; then
  RESET=true
fi

if [ "$RESET" = true ]; then
  supabase stop --no-backup
  echo '{"status":"stopped","reset":true}'
else
  supabase stop
  echo '{"status":"stopped","reset":false}'
fi
