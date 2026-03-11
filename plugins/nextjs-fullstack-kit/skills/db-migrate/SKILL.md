---
name: db-migrate
description: Create and apply a Supabase migration
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "description of schema change"
---

# Database Migration

Create a migration for: $ARGUMENTS

## Step 1: Understand Current Schema
- Use Supabase MCP to list current tables and their columns
- Read `src/types/database.ts` for current generated types
- Check `docs/generated/db-schema.md` for documented schema (if exists)

## Step 2: Write Migration SQL
Create a new migration file:
```bash
npx supabase migration new <descriptive_name>
```

Write the SQL in the generated file. Always include:
- `ALTER TABLE` / `CREATE TABLE` as needed
- RLS policies for any new tables (RLS is mandatory)
- Indexes for columns used in WHERE/JOIN
- Comments on non-obvious columns

## Step 3: Apply Locally

Ensure local Supabase is running first:
```bash
[ -f supabase/config.toml ] && (supabase status >/dev/null 2>&1 || ./scripts/supabase-local.sh)
```

Then apply:
```bash
npx supabase db reset
```

## Step 4: Regenerate Types
```bash
npx supabase gen types typescript --local > src/types/database.ts
```

## Step 5: Update Code
- Update affected `types.ts` files in domains to use new DB types
- Update `db.ts` query functions
- Update Zod schemas to match

## Step 6: Update Docs
- Update `docs/generated/db-schema.md` with the new schema
- Note the migration in `docs/exec-plans/active/` if part of a larger plan

## Step 7: Verify
- Use Supabase MCP to query the table and confirm structure
- Run affected tests

## Step 8: Push to production (optional)

If the migration should be applied to production now:
```bash
./scripts/supabase-push.sh --dry-run
```
Review the output. If it looks correct:
```bash
./scripts/supabase-push.sh --gen-types
```
