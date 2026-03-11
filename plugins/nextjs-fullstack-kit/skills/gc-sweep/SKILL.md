---
name: gc-sweep
description: Full codebase garbage collection sweep. Audits code quality, test health, dependencies, docs, and architecture. Three modes - "scan" (quick quality grades), "report" (full audit), or "fix" (auto-fix + commit).
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: <scan|report|fix>
---

# Garbage Collection Sweep

Mode: **$ARGUMENTS** (default: `report`)

## Scan Mode (quick quality grades)

If mode is `scan`, skip the full audit and only do per-domain grading:

1. For each domain in `src/domains/`:
   - **Architecture** (A-F): correct layer structure? (types → db → service → route → component)
   - **Type Safety** (A-F): Zod schemas at boundaries? No `any`?
   - **Test Coverage** (A-F): service.test.ts and route.test.ts exist? Tests assert behavior?
   - **Error Handling** (A-F): `.error` checked before `.data`? Structured logging?
   - **Code Size** (A-F): all files < 400 lines?
2. Global checks: linters pass? Unused deps? Middleware auth?
3. Update `docs/QUALITY_SCORE.md` with per-domain grades table and overall grade (A-F)
4. Done — skip all phases below.

---

## Full Audit (report and fix modes)

## Phase 1: Code Quality

Run all available linters and type checker:
```bash
npm run lint 2>&1 || true
npx tsc --noEmit 2>&1 || true
```
Run custom linters if they exist:
```bash
[ -f linters/check-layers.ts ] && npx tsx linters/check-layers.ts 2>&1 || true
[ -f linters/check-console-log.ts ] && npx tsx linters/check-console-log.ts 2>&1 || true
[ -f linters/check-file-size.ts ] && npx tsx linters/check-file-size.ts 2>&1 || true
```
Collect all violations.

## Phase 2: Test Health

Check that every service and API route has corresponding tests:
- Use Glob to find all `**/service.ts` and `**/route.ts` files
- For each, check if a matching `.test.ts` or `.spec.ts` exists
- Report missing test files

Run existing tests:
```bash
npm run test -- --reporter=verbose 2>&1 || true
```

## Phase 3: Dependency Hygiene

```bash
npm audit 2>&1 || true
npx depcheck 2>&1 || true
```
Report: vulnerable packages, unused dependencies, missing peer deps.

## Phase 4: Doc Freshness

If `/doc-gardening` skill exists, run it in report mode. Otherwise:
- Check all docs reference existing files
- Check cross-links are valid

## Phase 5: Architecture Drift

Check for files outside the expected domain structure:
- Use Glob to find all `.ts`/`.tsx` files in `src/`
- Verify each fits the expected project patterns
- Flag files in unexpected locations

## Phase 6: Golden Principles

If `docs/GOLDEN_PRINCIPLES.md` exists, cross-reference its rules:
- Every domain has `types.ts`?
- All API routes have Zod validation?
- Structured logger used everywhere?

## Phase 7: Log Hygiene

Check `.logs/` directory:
- Report file sizes
- If total > 50MB, warn about cleanup
- In `fix` mode: truncate logs older than 7 days

## Output

### Report Mode
Update `docs/QUALITY_SCORE.md` (create if missing) with:
- Date of sweep
- Score per phase (pass/warn/fail)
- Action items list
- Overall health grade (A/B/C/D/F)

### Fix Mode
For each auto-fixable issue:
1. Apply the fix
2. Verify the fix: linters pass, tests pass, no regressions
3. Commit with message: `chore: gc-sweep fix — [description]`

Issues that can't be auto-fixed → add to `docs/exec-plans/tech-debt-tracker.md`

## Phase 8: Exec Plan Staleness

If `docs/exec-plans/active/` exists and contains plans:
- For each active plan, check `git log` for related PRs in the last 7 days
- Flag plans with no progress in >7 days as "stale"
- In `fix` mode: add a note to the plan's Progress Log and warn the user
