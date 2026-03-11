---
name: deploy
description: Push local Supabase migrations to production and deploy the app to Vercel.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Agent
argument-hint: "[migrations-only | full]"
---

# Deploy to Production

Push local state to production: Supabase migrations + Vercel deploy.

**Modes:**
- `migrations-only` — push DB migrations only, skip app deploy
- `full` (default) — push migrations + deploy app

---

## Step 1: Pre-flight checks

Run all checks in parallel:

```bash
npm run test
npm run lint:all
git status --porcelain
```

If there are uncommitted changes — stop and ask the user to commit first.
If tests or linters fail — stop and report.

## Step 2: Verify local Supabase

```bash
supabase status >/dev/null 2>&1
```

If not running, warn: "Local Supabase is not running. Migrations will be pushed from files only."

## Step 3: Check linked project

```bash
cat supabase/.temp/project-ref 2>/dev/null
```

If no linked project:
- Ask user for their Supabase project ref
- Run `supabase link --project-ref <ref>`

## Step 4: Preview migrations (dry run)

```bash
./scripts/supabase-push.sh --dry-run
```

Show the user what SQL will be applied. Ask for confirmation before proceeding.

## Step 5: Push migrations

```bash
./scripts/supabase-push.sh --gen-types
```

Verify `src/types/database.ts` was regenerated. Run `npx tsc --noEmit` to check types still compile.

## Step 6: Deploy app (skip if `migrations-only`)

Check if Vercel CLI is available:

```bash
command -v vercel
```

If available:
```bash
vercel --prod
```

If not available, push to main and let CI handle it:
```bash
git push origin main
```

## Step 7: Post-deploy summary

Print a summary:
- Migrations applied (count + names)
- Types regenerated (yes/no)
- App deployed (URL or "skipped")
- Next steps (verify in browser, check logs)
