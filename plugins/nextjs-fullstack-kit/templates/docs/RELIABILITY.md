# Reliability Guide

## Supabase

### Connection Pooling
- Use connection pooler (port 6543) for serverless functions
- Max connections per function instance: keep low (1-3)

### RLS Performance
- Keep RLS policies simple — they run on every query
- Avoid subqueries in RLS policies; use `auth.uid()` directly
- Add indexes on columns used in RLS `USING` clauses

### Realtime Limits
- Max 200 concurrent connections on free tier
- Unsubscribe from channels on component unmount

### Storage
- Max file size: 50MB (free), 5GB (pro)
- Use signed URLs for private files

## Vercel

### Cold Starts
- Serverless functions: ~250ms cold start
- Keep function bundles small (< 1MB)
- Use edge runtime for latency-sensitive routes

### Function Timeout
- Hobby: 10s, Pro: 60s, Enterprise: 900s

### ISR / Cache
- Set `revalidate` explicitly on all data-fetching pages
- Use `revalidatePath()` / `revalidateTag()` for on-demand invalidation

### Build Size
- Monitor with `next build` output
- Keep First Load JS < 100KB per route

## Next.js

### Middleware Limits
- Runs on Edge Runtime — no Node.js APIs (fs, path, etc.)
- Max execution time: 25ms recommended

### Memory Leaks in Dev
- Dev mode hot reloads can leak instances
- Use singleton patterns in `src/lib/`

## Monitoring Checklist

| What | Tool | Frequency |
|------|------|-----------|
| JS errors | Sentry | Real-time alerts |
| API latency | Vercel Analytics | Daily review |
| DB performance | Supabase Dashboard | Weekly review |
| Build size | Vercel build logs | Every deploy |
| Web Vitals | `/api/vitals` + logs | Weekly review |

## Incident Response

1. **Identify**: Check Sentry for the error
2. **Scope**: Check Vercel for deploy issues, Supabase for data issues
3. **Reproduce**: Use Playwright to navigate and screenshot
4. **Fix**: Apply fix, validate (tests + linters), deploy
5. **Verify**: Confirm fix in production
