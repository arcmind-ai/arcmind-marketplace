---
name: new-project
description: Bootstrap a new Next.js + Supabase + Vercel project. Creates app with domain architecture, linters, scripts, structured logging, CI, and full docs knowledge base.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "project-name"
---

# New Project

Bootstrap a new agent-first project in the current directory.

If $ARGUMENTS contains a project name, create a new directory with that name first.

## Pre-flight

Check what already exists:
```bash
ls package.json 2>/dev/null && echo "EXISTING_PROJECT" || echo "EMPTY_DIR"
```

- **EXISTING_PROJECT** → skip Step 1 (Next.js setup), proceed to Step 2 (add missing pieces)
- **EMPTY_DIR** → full setup from Step 1

Ask the user before overwriting any existing files.

## Step 1: Create Next.js project

Only if no `package.json` exists.

**$ARGUMENTS must contain a project name.** If not provided, ask the user for one. Always create in a new directory — never use `.` as the target:

```bash
npx create-next-app@latest $ARGUMENTS --typescript --tailwind --eslint --app --src-dir --no-import-alias --use-npm --yes
cd $ARGUMENTS
```

Wait for it to complete, then install additional dependencies:

```bash
npm install @supabase/supabase-js zod pino pino-pretty
npm install -D tsx vitest @playwright/test supabase
```

## Step 1.5: Set up local Supabase

### 1.5a: Check prerequisites
```bash
docker info > /dev/null 2>&1 && echo "DOCKER_OK" || echo "DOCKER_NOT_RUNNING"
```

If Docker is not running — warn the user but continue. The project will work once Docker is started and `./scripts/supabase-local.sh` is run.

### 1.5b: Initialize Supabase project
```bash
npx supabase init
```
This creates the `supabase/` directory with `config.toml`.

### 1.5c: Start local Supabase
```bash
./scripts/supabase-local.sh
```
Parse the JSON output to get `apiUrl`, `anonKey`, `serviceRoleKey`, `studioUrl`.
The script auto-writes `.env.local` with local keys.

If Supabase fails to start (Docker not running, ports busy), warn and continue — the user can run `npm run supabase:start` later.

### 1.5d: Verify
```bash
cat .env.local | grep NEXT_PUBLIC_SUPABASE_URL
```
Confirm the local Supabase URL and keys are populated.

## Step 2: Create directory structure

Create the full domain architecture skeleton:

```bash
mkdir -p src/domains
mkdir -p src/lib/supabase
mkdir -p src/lib/providers
mkdir -p src/components/ui
mkdir -p src/components/layout
mkdir -p src/types
mkdir -p supabase/migrations
mkdir -p docs/design-docs
mkdir -p docs/exec-plans/active
mkdir -p docs/exec-plans/completed
mkdir -p docs/product-specs
mkdir -p docs/generated
mkdir -p linters
mkdir -p scripts
mkdir -p .logs
mkdir -p .github/workflows
```

## Step 3: Core source files

### `src/lib/logger.ts`
```typescript
import pino from "pino";
import { join } from "path";

const isDev = process.env.NODE_ENV !== "production";

const targets: pino.TransportTargetOptions[] = [];

if (isDev) {
  targets.push(
    {
      target: "pino/file",
      options: { destination: join(process.cwd(), ".logs", "app.ndjson"), mkdir: true },
      level: "trace",
    },
    {
      target: "pino-pretty",
      options: { colorize: true },
      level: "trace",
    }
  );
}

export const logger = isDev
  ? pino({ level: "trace" }, pino.transport({ targets }))
  : pino({ level: "info" });

export type LogType = "http" | "db" | "vital" | "app";
```

### `src/lib/supabase/client.ts`
```typescript
import { createClient as createSupabaseClient } from "@supabase/supabase-js";

export function createClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
```

### `src/lib/supabase/server.ts`
```typescript
import { createClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { logger } from "@/lib/logger";

export function createServerClient() {
  // For proper auth, use @supabase/ssr with cookie-based auth.
  // This is a basic setup — upgrade to cookie-based auth for production.
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

export function withLogging(
  client: ReturnType<typeof createClient>,
  table: string
) {
  const original = client.from(table);
  const startTime = Date.now();

  return new Proxy(original, {
    get(target, prop, receiver) {
      const value = Reflect.get(target, prop, receiver);
      if (typeof value === "function") {
        return (...args: unknown[]) => {
          const result = (value as Function).apply(target, args);
          if (result && typeof result.then === "function") {
            return result.then((res: any) => {
              const duration = Date.now() - startTime;
              logger.info({
                type: "db",
                table,
                op: String(prop),
                duration,
                rows: Array.isArray(res.data) ? res.data.length : res.data ? 1 : 0,
              });
              return res;
            });
          }
          return result;
        };
      }
      return value;
    },
  });
}
```

### `src/lib/supabase/admin.ts`
```typescript
import { createClient } from "@supabase/supabase-js";

export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}
```

### `src/middleware.ts`
```typescript
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const start = Date.now();
  const response = NextResponse.next();

  const duration = Date.now() - start;
  const logEntry = JSON.stringify({
    type: "http",
    method: request.method,
    path: request.nextUrl.pathname,
    duration,
    timestamp: new Date().toISOString(),
  });

  // Edge Runtime cannot use pino — structured JSON to stdout
  console.log(logEntry); // lint-allow-console

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

### `src/lib/report-vitals.ts`
```typescript
import type { Metric } from "web-vitals";

export function reportVitals(metric: Metric) {
  fetch("/api/vitals", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      name: metric.name,
      value: metric.value,
      rating: metric.rating,
      delta: metric.delta,
      id: metric.id,
    }),
  }).catch(() => {});
}
```

### `src/app/api/vitals/route.ts`
```typescript
import { NextResponse } from "next/server";
import { logger } from "@/lib/logger";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    logger.info({ type: "vital", ...body });
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: "Invalid body" }, { status: 400 });
  }
}
```

## Step 4: Linters

### `linters/check-layers.ts`

Read the linter from `${CLAUDE_SKILL_DIR}/../../linters/check-layers.ts` and write it to `linters/check-layers.ts` in the project.

### `linters/check-console-log.ts`

Read from `${CLAUDE_SKILL_DIR}/../../linters/check-console-log.ts` and write to `linters/check-console-log.ts`.

### `linters/check-file-size.ts`

Read from `${CLAUDE_SKILL_DIR}/../../linters/check-file-size.ts` and write to `linters/check-file-size.ts`.

## Step 5: Scripts

### `scripts/dev-server.sh`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/dev-server.sh` and write to `scripts/dev-server.sh`.

```bash
chmod +x scripts/dev-server.sh
```

### `scripts/dev-server-stop.sh`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/dev-server-stop.sh` and write to `scripts/dev-server-stop.sh`.

### `scripts/supabase-local.sh`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/supabase-local.sh` and write to `scripts/supabase-local.sh`.

### `scripts/supabase-local-stop.sh`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/supabase-local-stop.sh` and write to `scripts/supabase-local-stop.sh`.

### `scripts/supabase-push.sh`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/supabase-push.sh` and write to `scripts/supabase-push.sh`.

### `scripts/critical-journeys.json`

Read from `${CLAUDE_SKILL_DIR}/../../scripts/critical-journeys.json` and write to `scripts/critical-journeys.json`.

```bash
chmod +x scripts/*.sh
```

## Step 6: Package.json scripts

Add these scripts to `package.json` (merge with existing, don't overwrite):

```json
{
  "scripts": {
    "lint:layers": "npx tsx linters/check-layers.ts",
    "lint:console": "npx tsx linters/check-console-log.ts",
    "lint:filesize": "npx tsx linters/check-file-size.ts",
    "lint:all": "npm run lint && npm run lint:layers && npm run lint:console && npm run lint:filesize",
    "test": "vitest",
    "test:e2e": "playwright test",
    "supabase:start": "./scripts/supabase-local.sh",
    "supabase:stop": "./scripts/supabase-local-stop.sh",
    "supabase:push": "./scripts/supabase-push.sh",
    "db:reset": "supabase db reset",
    "db:gen-types": "supabase gen types typescript --local > src/types/database.ts"
  }
}
```

## Step 7: Documentation knowledge base

Create each doc file from the templates. Read the template from `${CLAUDE_SKILL_DIR}/../../templates/docs/` and write to the project.

### `CLAUDE.md`

Write a concise CLAUDE.md (under 200 lines) that serves as the agent's entry point.
Must contain these sections: `## Stack`, `## Quick Start`, `## Architecture`, `## Where to Look`, `## Key Rules`, `## MCP Servers Available`, `## Observability`, `## Debugging Workflow`, and the **## How you work** section below (copy it verbatim).

Use the reference project's CLAUDE.md as a template but adapt to the actual project name and any customizations the user mentioned in $ARGUMENTS.

The `## How you work` section **must be included exactly as written** — it is the routing logic that tells Claude how to handle natural language requests:

```markdown
## How you work

When the user describes work to do (without a slash command), follow this routing:

### 1. Assess scope

Read the request carefully. Check existing code in `src/domains/`, `src/app/`, and `supabase/migrations/` to understand what exists.

Classify the task:
- **Small** — single file or small change within one domain, no DB changes
- **Medium** — several files in one domain, or a new simple domain (1-2 layers)
- **Large** — multiple domains, DB migrations, new architecture, 4+ files across layers

### 2. Execute based on scope

**Small task:**
1. Write the code
2. Run tests: `npm run test`
3. Run linters: `npm run lint:all`
4. Check for errors in logs: `grep '"level":50' .logs/app.ndjson | tail -5`
5. If UI changed — verify with Playwright (browser_navigate + browser_screenshot + browser_console_messages)
6. Commit with descriptive message

**Medium task:**
1. State your plan briefly: which files, which layers (types → db → service → route → UI)
2. Build layer by layer, writing tests alongside
3. Run full validation (tests + linters + logs + visual check if UI)
4. Self-review against architecture rules
5. Spawn code-reviewer agent on the diff
6. Fix issues (up to 3 iterations)
7. Commit with descriptive message

**Large task:**
1. Create an exec plan in `docs/exec-plans/active/` — list all tasks with dependencies
2. Show the plan to the user and wait for confirmation
3. Execute task by task:
   - For each task: build → test → validate → commit
   - Between tasks: quick quality check (linters + tests still green?)
   - If a task fails 3 times: mark as blocked, move to next
4. After all tasks: run gc-sweep scan, self-review the full diff
5. Create one PR for the entire plan
6. Update exec plan → move to `docs/exec-plans/completed/`

### 3. Always do after any code change

- Update `docs/generated/db-schema.md` if you created a migration
- Update `ARCHITECTURE.md` if you added a new domain
- If docs reference changed code, fix them (or note what needs fixing)

### 4. When in doubt

- If the request is ambiguous → ask clarifying questions before writing code
- If you're unsure about architecture decisions → check GOLDEN_PRINCIPLES.md and ARCHITECTURE.md
- If the user says "deploy" → use `/deploy` (requires explicit confirmation)
- If the user says "review" or "check quality" → run gc-sweep scan + review the diff
```

### `ARCHITECTURE.md`

Write the full architecture doc describing the domain structure, layer rules, cross-cutting concerns, database strategy, testing strategy, and observability.

### Docs directory

Create these files from templates (read each from `${CLAUDE_SKILL_DIR}/../../templates/docs/`):

| Template | Destination |
|----------|-------------|
| `GOLDEN_PRINCIPLES.md` | `docs/GOLDEN_PRINCIPLES.md` |
| `REVIEW_STANDARDS.md` | `docs/REVIEW_STANDARDS.md` |
| `DESIGN.md` | `docs/DESIGN.md` |
| `RELIABILITY.md` | `docs/RELIABILITY.md` |
| `PRODUCT_SENSE.md` | `docs/PRODUCT_SENSE.md` |
| `PLANS.md` | `docs/PLANS.md` |
| `exec-plan-template.md` | `docs/exec-plans/exec-plan-template.md` |

Also create:

### `docs/SECURITY.md`
```markdown
# Security

## Authentication
- All protected routes are in `src/app/(auth)/` layout with auth check
- Session refresh on every request via middleware
- API routes check auth where needed

## Authorization (RLS)
- Every table has Row Level Security enabled — no exceptions
- Use `auth.uid()` in RLS policies
- Test RLS policies via Supabase MCP: query as different users

## Data Validation
- All API inputs validated with Zod schemas
- Check `.error` before `.data` on every Supabase call
- No raw user input in SQL queries

## Secrets
- Never put secrets in `NEXT_PUBLIC_*` env vars
- Service role key only used server-side in `lib/supabase/admin.ts`
- `.env.local` for dev, Vercel dashboard for prod
```

### `docs/FRONTEND.md`
```markdown
# Frontend Patterns

## Server vs Client Components
- Default to Server Components
- Use `"use client"` only when you need interactivity (onClick, useState, etc.)
- Data fetching in Server Components or API routes, never in client components

## Data Fetching
- Server Components: call service functions directly
- Client Components: call API routes via fetch

## Error Handling
- Use error boundaries (`error.tsx`) per route segment
- Show user-friendly messages, log details with structured logger
- Loading states via `loading.tsx` — use skeleton placeholders, not spinners
```

### `docs/QUALITY_SCORE.md`
```markdown
# Quality Score

Last scan: (not yet run)

Run `/gc-sweep scan` to populate this file.

| Domain | Architecture | Types | Tests | Errors | Size | Grade |
|--------|-------------|-------|-------|--------|------|-------|
| | | | | | | |

## Action Items
```

### `docs/design-docs/index.md`
```markdown
# Design Docs

## Index

| Doc | Status | Date |
|-----|--------|------|
| [Core Beliefs](./core-beliefs.md) | active | — |

## Process
1. Write a design doc before building anything non-trivial
2. Ask Claude to review the design doc
3. Reference the doc in your exec plan
```

### `docs/design-docs/core-beliefs.md`
```markdown
# Core Beliefs

## Agent-First Development
- Agents write code, humans design environments
- Repository is the system of record — not Slack, not Google Docs
- Enforce invariants mechanically, not by convention
- Agent legibility > human stylistic preferences

## Architecture
- Strict domain layers with forward-only dependencies
- Golden principles are mechanically verifiable
- Garbage collection > manual cleanup
- Agent-to-agent review before human review
```

### `docs/generated/db-schema.md`
```markdown
# Database Schema

> Auto-updated by `/db-migrate`. Do not edit manually.

No migrations yet. Run `/db-migrate` to create your first migration.
```

### `docs/exec-plans/tech-debt-tracker.md`
```markdown
# Tech Debt Tracker

Items flagged by `/gc-sweep` that cannot be auto-fixed.

| Date | Issue | Severity | Status |
|------|-------|----------|--------|
| | | | |
```

## Step 8: MCP configuration

### `.mcp.json`
```json
{
  "mcpServers": {
    "supabase": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}",
        "SUPABASE_PROJECT_REF": "${SUPABASE_PROJECT_REF}"
      }
    },
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    }
  }
}
```

## Step 9: CI workflows

### `.github/workflows/ci.yml`

Read from `${CLAUDE_SKILL_DIR}/../../templates/ci/ci.yml` and write to `.github/workflows/ci.yml`.

### `.github/workflows/knowledge-base-check.yml`

Read from `${CLAUDE_SKILL_DIR}/../../templates/ci/knowledge-base-check.yml` and write to `.github/workflows/knowledge-base-check.yml`.

## Step 10: Environment and gitignore

### `.env.example`
```bash
# Supabase — LOCAL (auto-filled by ./scripts/supabase-local.sh)
# Run `npm run supabase:start` to populate these automatically
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<auto-filled-by-supabase-local>
SUPABASE_SERVICE_ROLE_KEY=<auto-filled-by-supabase-local>
SUPABASE_DB_URL=<auto-filled-by-supabase-local>

# Supabase — PRODUCTION (fill manually for deploy)
# Get these from: supabase.com/dashboard → Settings → API
SUPABASE_ACCESS_TOKEN=your-supabase-access-token
SUPABASE_PROJECT_REF=your-project-ref

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### Append to `.gitignore`
```
# Project
.logs/
.dev-server.pid
.env.local
```

## Step 11: Vitest config

### `vitest.config.ts`
```typescript
import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
});
```

## Step 12: Validate setup

Before committing, verify that all critical pieces are in place:

```bash
echo "=== Validating project setup ==="
ERRORS=0

# Core files
for f in src/lib/logger.ts src/lib/supabase/client.ts src/lib/supabase/server.ts src/lib/supabase/admin.ts src/middleware.ts vitest.config.ts; do
  [ -f "$f" ] || { echo "MISSING: $f"; ERRORS=$((ERRORS+1)); }
done

# Linters
for f in linters/check-layers.ts linters/check-console-log.ts linters/check-file-size.ts; do
  [ -f "$f" ] || { echo "MISSING: $f"; ERRORS=$((ERRORS+1)); }
done

# Scripts
for f in scripts/dev-server.sh scripts/supabase-local.sh scripts/supabase-push.sh; do
  [ -f "$f" ] || { echo "MISSING: $f"; ERRORS=$((ERRORS+1)); }
  [ -x "$f" ] || { echo "NOT EXECUTABLE: $f"; ERRORS=$((ERRORS+1)); }
done

# Docs
for f in docs/GOLDEN_PRINCIPLES.md docs/REVIEW_STANDARDS.md CLAUDE.md ARCHITECTURE.md; do
  [ -f "$f" ] || { echo "MISSING: $f"; ERRORS=$((ERRORS+1)); }
done

# npm scripts
for s in lint:layers lint:console lint:filesize test supabase:start supabase:stop db:reset db:gen-types; do
  node -e "const p=require('./package.json'); process.exit(p.scripts?.['$s'] ? 0 : 1)" 2>/dev/null || { echo "MISSING npm script: $s"; ERRORS=$((ERRORS+1)); }
done

if [ $ERRORS -eq 0 ]; then
  echo "All checks passed."
else
  echo "WARNINGS: $ERRORS issues found. Review above and fix before continuing."
fi
```

If there are missing files or scripts, fix them before proceeding to the commit step.

## Step 13: Git init and first commit

```bash
git init 2>/dev/null || true
git add \
  package.json package-lock.json tsconfig.json next.config.ts vitest.config.ts \
  .env.example .gitignore .eslintrc.json .mcp.json \
  src/ supabase/ linters/ scripts/ docs/ .github/ \
  CLAUDE.md ARCHITECTURE.md
git commit -m "feat: bootstrap project

Next.js + Supabase + Vercel with:
- Domain architecture (types → db → service → route → component)
- Custom linters (layers, console.log, file size)
- Structured logging (pino → .logs/app.ndjson)
- MCP integrations (Supabase, Playwright)
- Docs knowledge base (17 golden principles)
- CI workflows (lint, test, doc validation)
- Scripts (dev-server with worktree isolation)

Scaffolded by /new-project — nextjs-fullstack-kit"
```

## Step 14: Summary

Print a summary of what was created:

```
Project initialized!

Created:
  src/lib/          — logger, supabase clients, providers
  src/domains/      — ready for your first domain
  linters/          — check-layers, check-console-log, check-file-size
  scripts/          — dev-server with worktree isolation
  docs/             — full knowledge base (17 golden principles)
  .github/workflows — CI + knowledge base validation
  .mcp.json         — Supabase, Playwright MCPs

Next steps:
  1. Make sure Docker is running
  2. npm run supabase:start        # start local Supabase + auto-fill .env.local
  3. npm run dev                   # start Next.js against local Supabase
  4. Create your first domain:     mkdir -p src/domains/users
  5. Just start talking to Claude — describe what you want to build!

Local Supabase:
  npm run supabase:start           # start local Supabase
  npm run supabase:stop            # stop local Supabase
  npm run db:reset                 # reset local DB (re-apply all migrations)
  npm run db:gen-types             # regenerate TypeScript types from local DB

Deploy to production:
  supabase link --project-ref <id> # link to cloud project (one-time)
  Just say "deploy" to Claude      # push migrations + deploy app
```
