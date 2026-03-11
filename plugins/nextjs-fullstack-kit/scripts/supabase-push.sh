#!/bin/bash
# Push local Supabase migrations to production.
# Requires: SUPABASE_ACCESS_TOKEN and linked project (supabase link).
# Usage: ./scripts/supabase-push.sh [--dry-run] [--gen-types]

set -euo pipefail

DRY_RUN=false
GEN_TYPES=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --gen-types) GEN_TYPES=true ;;
  esac
done

# --- Pre-flight checks ---

if ! command -v supabase &>/dev/null; then
  echo '{"error":"Supabase CLI not found. Install with: npm install -D supabase"}' >&2
  exit 1
fi

# Check if project is linked (supabase/.temp/project-ref exists after `supabase link`)
if [ ! -f "supabase/.temp/project-ref" ]; then
  echo '{"error":"No linked Supabase project. Run: supabase link --project-ref <your-project-id>"}' >&2
  exit 1
fi

PROJECT_REF=$(cat supabase/.temp/project-ref)

# --- Dry run ---

if [ "$DRY_RUN" = true ]; then
  echo "Dry run — previewing migrations for project ${PROJECT_REF}..." >&2
  supabase db push --dry-run
  echo "{\"status\":\"dry-run\",\"projectRef\":\"${PROJECT_REF}\"}"
  exit 0
fi

# --- Push ---

echo "Pushing migrations to project ${PROJECT_REF}..." >&2

if ! supabase db push; then
  echo '{"error":"supabase db push failed. Check logs above."}' >&2
  exit 1
fi

# --- Optional: regenerate types from remote ---

if [ "$GEN_TYPES" = true ]; then
  echo "Regenerating types from remote..." >&2
  supabase gen types typescript --project-id "$PROJECT_REF" > src/types/database.ts
fi

echo "{\"status\":\"pushed\",\"projectRef\":\"${PROJECT_REF}\"}"
