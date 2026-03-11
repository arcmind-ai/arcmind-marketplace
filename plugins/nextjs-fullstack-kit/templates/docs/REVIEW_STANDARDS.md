# Code Review Standards

## Severity Definitions

| Severity | Description | Action |
|----------|-------------|--------|
| **blocker** | Breaks functionality, security vulnerability, data loss risk | Must fix before merge |
| **major** | Architecture violation, missing tests, performance issue | Must fix before merge |
| **minor** | Code style, naming, minor refactoring opportunity | Should fix, can defer |
| **nit** | Preference, optional improvement | Nice to have |

## Review Checklist

### 1. Architecture
- [ ] Layer dependencies flow forward only
- [ ] No cross-domain direct DB imports
- [ ] Cross-cutting concerns use providers
- [ ] No file exceeds 400 lines

### 2. Security
- [ ] RLS policies exist for all new/modified tables
- [ ] Auth checks on all protected API routes
- [ ] All API inputs validated with Zod schemas
- [ ] No secrets or env vars hardcoded
- [ ] No SQL injection vectors

### 3. Test Coverage
- [ ] New service functions have tests
- [ ] New API routes have tests
- [ ] Tests actually assert behavior
- [ ] Edge cases covered

### 4. Performance
- [ ] No N+1 query patterns
- [ ] Large lists use pagination
- [ ] Heavy components use dynamic imports
- [ ] Images use `next/image`

### 5. Code Quality
- [ ] Uses structured logger, not `console.log`
- [ ] No `any` types
- [ ] Clean imports (no unused, no circular)
