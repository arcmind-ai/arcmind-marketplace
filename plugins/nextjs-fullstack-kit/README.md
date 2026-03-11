# nextjs-fullstack-kit

Agent-first development toolkit for Next.js + Supabase + Vercel projects. Gives Claude Code superpowers: local Supabase, worktree testing, structured logging, agent-to-agent review, garbage collection sweeps, and CI templates.

## Install

```
/plugin marketplace add buildoak/arcmind-marketplace
/plugin install nextjs-fullstack-kit@arcmind-marketplace
```

## How it works

After installing, run `/new-project my-app` to bootstrap a full project. From that point on, **just talk to Claude** — describe what you want to build, fix, or change in plain language. Claude automatically picks the right approach based on task complexity:

- **Small tasks** — writes code, runs tests, commits
- **Medium tasks** — plans first, builds layer-by-layer, runs code review
- **Large tasks** — creates an execution plan, shows you for approval, then executes task-by-task with one PR at the end

No slash commands needed after setup. Claude handles routing, testing, review, and documentation internally.

## What you get

### Skills (12)
| Skill | Command | What it does |
|-------|---------|--------------|
| New Project | `/new-project [name]` | Bootstrap a new project with full stack setup |
| Implement | `/implement <description>` | End-to-end feature loop: build → test → review → PR |
| Auto Fix | `/auto-fix <bug>` | Autonomous bug fix: investigate → fix → validate → PR |
| Browser Inspect | `/browser-inspect [url]` | Deep Playwright inspection: JS errors, performance, accessibility |
| DB Migrate | `/db-migrate <description>` | Create and apply a Supabase migration with types regeneration |
| Deploy | `/deploy` | Push local Supabase migrations to production and deploy app to Vercel |
| Doc Gardening | `/doc-gardening` | Scan and fix stale documentation |
| Exec Plan | `/exec-plan <command>` | Manage execution plans: create, status, complete, list, run |
| GC Sweep | `/gc-sweep <scan\|report\|fix>` | Codebase audit: quality grades, linters, tests, deps, docs, architecture |
| Frontend Design | `/frontend-design [description]` | Generate distinctive, production-grade UI that avoids generic AI aesthetics |
| Read Logs | `/read-logs <filter>` | Query structured logs: `errors`, `slow-queries`, `slow-requests`, `vitals`, `tail` |
| Worktree Test | `/worktree-test` | Run tests in an isolated git worktree with a dev server on a random port |

### Agents (5)
| Agent | When Claude invokes it | Collaborates with |
|-------|----------------------|-------------------|
| `task-driver` | Executing plans — picks tasks, delegates, validates, loops | All agents |
| `code-reviewer` | Reviewing code changes, PRs, implementation feedback | db-architect, quality-guard, bug-detective |
| `db-architect` | Schema design, migrations, RLS policies, query optimization | code-reviewer, bug-detective |
| `bug-detective` | Bug reports, errors, unexpected behavior | db-architect, quality-guard, code-reviewer |
| `quality-guard` | Pre-commit/PR quality checks, codebase health assessment | bug-detective, db-architect, code-reviewer |

### Hooks (3)
| Hook | Trigger | What it does |
|------|---------|--------------|
| `block-dangerous.sh` | PreToolUse (Bash) | Blocks DROP TABLE, migration deletion, force push; warns on `supabase db push` |
| `lint-on-save.sh` | PostToolUse (Edit/Write) | Runs ESLint on changed TypeScript files |
| `post-task-quality.sh` | Stop | Reminds about uncommitted changes |

### Linters (3)
Custom linters with agent-legible error messages:
- **check-layers.ts** — Enforce layer dependency rules (Types → DB → Service → Route → UI)
- **check-console-log.ts** — No bare `console.log` in `src/` (use structured logger)
- **check-file-size.ts** — No file > 400 lines

### Scripts (5)
- **dev-server.sh** — Start dev server on random port, auto-checks local Supabase status
- **dev-server-stop.sh** — Stop the dev server
- **supabase-local.sh** — Start local Supabase (Docker), auto-configure `.env.local`
- **supabase-local-stop.sh** — Stop local Supabase (`--reset` to clear volumes)
- **supabase-push.sh** — Push migrations to production (`--dry-run`, `--gen-types`)

### Templates
Doc and CI templates to copy into your project:
- `templates/docs/` — PRODUCT_SENSE, PLANS, DESIGN, RELIABILITY, REVIEW_STANDARDS, GOLDEN_PRINCIPLES
- `templates/ci/` — GitHub Actions workflows (CI + knowledge base validation)

## Local Supabase workflow

The plugin is designed to work with local Supabase out of the box:

```bash
# 1. Start local Supabase (auto-fills .env.local)
npm run supabase:start

# 2. Start dev server (auto-checks Supabase status)
npm run dev

# 3. Develop, test, iterate — just talk to Claude

# 4. When ready for production:
supabase link --project-ref <your-project-id>   # one-time
/deploy                                           # push migrations + deploy
```

## Requirements

- Git repository
- Node.js project with `npm`
- `tsx` dev dependency (`npm i -D tsx`)
- **Docker** — required for local Supabase
- **Supabase CLI** — `npm i -D supabase` (installed automatically by `/new-project`)

## Works best with

- **Supabase MCP** — for `/db-migrate`, bug investigation
- **Playwright MCP** — for `/worktree-test`, `/browser-inspect`, visual verification
- **Sentry MCP** — for bug investigation
