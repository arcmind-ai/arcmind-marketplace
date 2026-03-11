#!/bin/bash
# Pre-merge safety check: block auto-merge if protected paths are modified.
# Used by /auto-fix and /implement before gh pr merge.
# Usage: ./scripts/pre-merge-check.sh [PR_NUMBER]

set -euo pipefail

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
  echo '{"allowed":false,"reason":"No PR number provided"}'
  exit 1
fi

# Protected paths that always require human review
PROTECTED_PATTERNS=(
  "src/middleware.ts"
  "supabase/migrations/"
  ".env"
  "docs/SECURITY.md"
  "package.json"
  "package-lock.json"
  ".claude/"
  "CLAUDE.md"
)

CHANGED_FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
  echo '{"allowed":false,"reason":"Could not fetch PR diff"}'
  exit 1
fi

BLOCKED_FILES=()
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  while IFS= read -r match; do
    [ -n "$match" ] && BLOCKED_FILES+=("$match")
  done < <(echo "$CHANGED_FILES" | grep -F "$pattern" || true)
done

if [ ${#BLOCKED_FILES[@]} -gt 0 ]; then
  # Use jq to produce valid JSON
  BLOCKED_JSON=$(printf '%s\n' "${BLOCKED_FILES[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')
  jq -n --argjson files "$BLOCKED_JSON" '{allowed: false, reason: "Protected paths modified", files: $files}'
  exit 1
fi

echo '{"allowed":true}'
exit 0
