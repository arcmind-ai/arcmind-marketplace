---
name: worktree-test
description: Run tests in an isolated git worktree. Starts a dev server on a random port, runs Playwright tests, captures screenshots and console errors, then cleans up.
allowed-tools: Read, Grep, Glob, Bash, Agent
argument-hint: [optional: specific page or test to run]
---

# Worktree Isolation Test

Test the current changes in an isolated git worktree so the main working tree stays clean.

## Step 1: Commit current changes

Ensure all changes are committed (or stashed) so the worktree has them.

## Step 2: Spawn isolated agent

Use the Agent tool with `isolation: "worktree"` to launch a sub-agent. The sub-agent should:

### 2a. Start dev server (with ephemeral log isolation)

First, ensure local Supabase is running (if the project uses it):
```bash
[ -f supabase/config.toml ] && (supabase status >/dev/null 2>&1 || ./scripts/supabase-local.sh)
```

Then start the dev server:
```bash
./scripts/dev-server.sh
```
Parse the JSON output to get `port`, `logFile`, `worktreeId`, and `logDir`.
The script auto-detects worktree context and creates isolated logs in `.logs/{worktreeId}/`.

If the script doesn't exist, use:
```bash
PORT=$((3001 + RANDOM % 99))
npm run dev -- -p $PORT &
```

### 2b. Run tests via Playwright MCP
- `browser_navigate` to `http://localhost:{port}`
- `browser_take_screenshot` — capture initial state
- `browser_console_messages` — check for JS errors
- `browser_snapshot` — capture DOM structure

If $ARGUMENTS specifies a page or test:
- Navigate to that specific page
- Perform the specified test actions
- Screenshot each step

### 2c. Run automated tests
```bash
npm run test
```
If E2E tests exist:
```bash
npx playwright test --reporter=list
```

### 2d. Check logs for errors
Use the `logFile` path from the dev-server JSON output (isolated per worktree).
Store it in a variable, e.g. `LOG_FILE=$(echo '$DEV_SERVER_OUTPUT' | jq -r '.logFile')`, then:
```bash
grep '"level":50' "$LOG_FILE" || echo "No errors in logs"
```
Also check for slow queries and slow requests:
```bash
cat "$LOG_FILE" | jq 'select(.type == "db" and .duration > 100)' 2>/dev/null | tail -10
cat "$LOG_FILE" | jq 'select(.type == "http" and .duration > 500)' 2>/dev/null | tail -10
```

### 2e. Clean up
```bash
./scripts/dev-server-stop.sh
```
Or kill the dev server process directly.

## Step 3: Report results

The sub-agent should return:
- **Screenshots** taken during testing
- **Console errors** (if any)
- **Test results** (pass/fail counts)
- **Log errors** (if any)
- **Verdict**: PASS or FAIL with details

If FAIL, list each issue with file location and suggested fix.
