---
name: auto-fix
description: End-to-end autonomous bug fix loop. Reproduces bug, records evidence, implements fix, validates, runs agent review, opens PR, and optionally auto-merges. Full Harness-style autonomy.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent, Skill
argument-hint: <bug description or GitHub issue URL>
---

# Autonomous Fix Loop

End-to-end fix for: **$ARGUMENTS**

## Pre-flight: Check autonomy level

Read `CLAUDE.md` and look for `autonomy_level` setting:
- `assisted` → Stop after creating PR, ask human to review and merge
- `semi-auto` → Create PR and request human review, do not merge
- `full-auto` → Full loop: fix → PR → agent review → auto-merge

Default to `semi-auto` if not specified.

## Step 1: Reproduce the bug

### 1a. Gather context
**If GitHub issue URL:**
- Use `gh issue view` to get full details
- Extract: error message, stack trace, affected URL, steps to reproduce

**If text description:**
- Search codebase for related files
- Check `.logs/app.ndjson` for related errors

### 1b. Start dev server in worktree
Use the Agent tool with `isolation: "worktree"` for the entire fix loop.

Inside the worktree agent, ensure local Supabase is running first:
```bash
[ -f supabase/config.toml ] && (supabase status >/dev/null 2>&1 || ./scripts/supabase-local.sh)
```

Then start the dev server:
```bash
./scripts/dev-server.sh
```
Parse JSON output to get `port`.

### 1c. Record "BEFORE" evidence
Use Playwright MCP:
1. `browser_navigate` to the affected URL on `http://localhost:{port}`
2. `browser_take_screenshot` → save as "before" evidence
3. `browser_console_messages` → capture JS errors
4. `browser_network_requests` → capture failed API calls
5. `browser_snapshot` → capture DOM state

Document reproduction steps and observed behavior.

### 1d. Verify bug is reproduced
If the bug cannot be reproduced:
- Log findings and escalate to human
- Do NOT proceed with a speculative fix

## Step 2: Implement the fix

### 2a. Identify root cause
Based on evidence from Step 1:
- Stack trace → pinpoint the failing code
- Network errors → check API route logic
- Console errors → check client-side code
- Data issues → check DB queries / RLS policies

### 2b. Write the fix
- Make minimal, focused changes
- Follow project architecture (check `ARCHITECTURE.md`)
- Validate at boundaries (Zod schemas if touching API)
- Use structured logger, never `console.log`

### 2c. Write or update tests
- Add a test that would have caught this bug
- Ensure existing tests still pass:
```bash
npm run test 2>&1
```

## Step 3: Validate the fix

### 3a. Record "AFTER" evidence
Use Playwright MCP:
1. `browser_navigate` to the same affected URL
2. `browser_take_screenshot` → save as "after" evidence
3. `browser_console_messages` → verify no JS errors
4. `browser_network_requests` → verify no failed calls
5. `browser_snapshot` → verify correct DOM state

### 3b. Run full test suite
```bash
npm run test 2>&1
npx playwright test --reporter=list 2>&1 || true
```

### 3c. Run linters
```bash
npm run lint 2>&1 || true
npx tsx linters/check-layers.ts 2>&1 || true
npx tsx linters/check-console-log.ts 2>&1 || true
npx tsx linters/check-file-size.ts 2>&1 || true
```

### 3d. Check logs for new errors
```bash
grep '"level":50' .logs/app.ndjson | tail -5 || echo "No errors"
```

If any validation fails → go back to Step 2 and iterate (max 3 attempts).

## Step 4: Self-review

Run the self-review checklist:
- Architecture: layer deps correct?
- Types: Zod schemas at boundaries?
- Security: no secrets, RLS intact?
- Tests: new test covers the bug?
- Logs: structured logging used?
- File size: no file > 400 lines?

Fix any issues found.

## Step 5: Agent review

Spawn a `code-reviewer` agent to review changes:

> You are a senior code reviewer. Review the changes in this worktree.
> Read: CLAUDE.md, ARCHITECTURE.md, docs/REVIEW_STANDARDS.md, docs/GOLDEN_PRINCIPLES.md
> Run: `git diff main...HEAD`
> Check: architecture, security, tests, performance, product sense, code quality
> Output ISSUE blocks and a VERDICT: APPROVED or CHANGES_REQUESTED

- **APPROVED** → proceed to Step 6
- **CHANGES_REQUESTED** → fix issues, re-run reviewer (max 3 iterations)
- **3 failures** → escalate to human, do NOT proceed

## Step 6: Commit changes

Commit all changes with a descriptive message:
```bash
git add [changed files by name]
git commit -m "fix: [concise description of the bug fix]"
```

## Step 7: Create PR (only if running standalone)

**If called from task-driver (executing an exec plan):** SKIP this step and Step 8 — task-driver creates one PR for the entire plan. Just commit and return.

**If running standalone (user invoked directly):** Create a PR:

```bash
gh pr create \
  --title "fix: [concise description of the bug fix]" \
  --body "$(cat <<'EOF'
## Bug Fix

**Problem:** [describe the bug]
**Root cause:** [what was wrong]
**Fix:** [what was changed]

## Evidence

### Before
[Description of broken behavior + screenshot reference]

### After
[Description of fixed behavior + screenshot reference]

## Test plan
- [ ] New test added that reproduces the original bug
- [ ] All existing tests pass
- [ ] Linters pass
- [ ] Agent review: APPROVED

---
Generated by `/auto-fix` — autonomous bug fix loop
EOF
)"
```

## Step 8: Auto-merge (standalone only)

### `full-auto` mode:
1. Wait for CI to pass:
```bash
gh pr checks --watch
```
2. Check if any protected paths were modified:
```bash
gh pr diff --name-only | grep -E '(middleware\.ts|supabase/migrations|\.env|docs/SECURITY\.md)' && echo "PROTECTED" || echo "SAFE"
```
3. If SAFE and CI passes:
```bash
gh pr merge --squash --auto --delete-branch
```
4. If PROTECTED → add comment requesting human review, do NOT merge

### `semi-auto` mode:
- PR is created, add comment: "Agent review passed. Ready for human review."
- Do NOT merge

### `assisted` mode:
- PR is created, no auto-merge attempted
- Notify user of PR URL

## Step 9: Clean up

```bash
./scripts/dev-server-stop.sh
```

## Step 10: Update exec plan (if applicable)

If an active exec plan in `docs/exec-plans/active/` references this bug:
- Check off the related task
- Increment agent run count
- Add entry to Progress Log with commit hash and date
- Commit: `docs: update exec plan progress`

## Escalation rules

Escalate to human immediately if:
- Bug cannot be reproduced
- Fix requires database migration
- Fix touches authentication/authorization logic
- Agent review fails 3 times
- CI fails after fix and cause is unclear
- Protected paths need changes
