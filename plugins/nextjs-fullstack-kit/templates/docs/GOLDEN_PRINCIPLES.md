# Golden Principles — Mechanical Rules

These are concrete, checkable rules that the GC sweep (`/gc-sweep`) enforces.

## Code Organization
1. **Shared utilities > hand-rolled helpers** — check `src/lib/` before writing a new utility
2. **No file > 400 lines** — split into smaller modules
3. **Every domain has `types.ts`** — domain types live here, not scattered
4. **All schemas named `{Domain}{Entity}Schema`** — e.g., `UserProfileSchema`

## Data Safety
5. **Validate at boundaries** — Zod schemas on all API inputs and DB results
6. **All API routes have Zod input validation** — no raw `request.json()` without parsing
7. **RLS on every table** — no exceptions
8. **Check `.error` before `.data`** — every Supabase call checks the error first

## Observability
9. **Structured logging everywhere** — use the project logger, never bare `console.log`
10. **HTTP requests are logged** — middleware captures method, path, status, duration
11. **DB queries are logged** — use logging wrapper for DB queries

## Architecture
12. **Layer deps flow forward only** — Types → Schema → DB → Service → API → UI
13. **Cross-cutting through providers** — auth, analytics, feature flags
14. **Client components are pure** — no data fetching in `"use client"` components

## Testing
15. **Every service function has a test** — happy path + error case
16. **Every API route has a test** — happy path + error case
17. **Tests assert behavior** — not just "doesn't throw"
