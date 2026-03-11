#!/bin/bash
# PostToolUse hook for Edit/Write. Runs linters on changed files.
# Reads tool input from stdin (JSON) to get the file path.

set -euo pipefail

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Only lint TypeScript/JavaScript files
if [[ "$FILE" == *.ts ]] || [[ "$FILE" == *.tsx ]] || [[ "$FILE" == *.js ]] || [[ "$FILE" == *.jsx ]]; then
  # Run ESLint on the file if available
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if command -v npx &> /dev/null && { [ -f "$PROJECT_ROOT/eslint.config.mjs" ] || [ -f "$PROJECT_ROOT/.eslintrc.json" ] || [ -f "$PROJECT_ROOT/eslint.config.js" ]; }; then
    npx eslint "$FILE" --no-error-on-unmatched-pattern >&2
  fi
fi

exit 0
