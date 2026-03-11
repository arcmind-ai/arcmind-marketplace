---
name: browser-inspect
description: Deep browser inspection using Playwright MCP. Runs critical user journeys, captures performance metrics, checks for JS errors, failed network requests, and accessibility issues.
allowed-tools: Read, Grep, Glob, Bash, Agent
argument-hint: [optional: specific page URL, journey name, or "all"]
---

# Browser Inspection

Deep browser inspection for: **$ARGUMENTS** (default: all critical journeys)

## Step 1: Start dev server

Check if dev server is already running:
```bash
if [ -f .dev-server.pid ]; then
  # Find server-meta.json (may be in .logs/ or .logs/<worktreeId>/)
  META=$(find .logs -name server-meta.json -maxdepth 2 2>/dev/null | head -1)
  if [ -n "$META" ]; then
    PORT=$(jq -r '.port' "$META")
    curl -s http://localhost:$PORT > /dev/null
  fi
fi
```

If not running, ensure local Supabase is up first:
```bash
[ -f supabase/config.toml ] && (supabase status >/dev/null 2>&1 || ./scripts/supabase-local.sh)
./scripts/dev-server.sh
```
Parse JSON output to get `port`.

## Step 2: Determine what to inspect

**If specific URL provided:**
- Inspect that single page (go to Step 3)

**If journey name provided:**
- Read `scripts/critical-journeys.json`
- Find the named journey and execute it (go to Step 4)

**If "all" or no argument:**
- Read `scripts/critical-journeys.json`
- Execute all journeys (go to Step 4)
- If no journeys file exists, inspect the homepage and any routes found in `src/app/`

## Step 3: Single page deep inspection

Use Playwright MCP for comprehensive page analysis:

### 3a. Navigation & screenshot
- `browser_navigate` to the target URL
- `browser_take_screenshot` — visual state

### 3b. DOM analysis
- `browser_snapshot` — full accessibility tree
- Check for: missing alt text, empty links, missing labels, heading hierarchy

### 3c. Console errors
- `browser_console_messages` — capture all messages
- Flag: errors, unhandled promise rejections, deprecation warnings

### 3d. Network analysis
- `browser_network_requests` — capture all requests
- Flag: 4xx/5xx responses, slow requests (>1s), CORS errors, mixed content

### 3e. Performance metrics
Use `browser_evaluate` to extract Web Vitals:
```javascript
() => {
  return JSON.stringify({
    navigation: performance.getEntriesByType('navigation')[0],
    resources: performance.getEntriesByType('resource')
      .filter(r => r.duration > 500)
      .map(r => ({ name: r.name, duration: Math.round(r.duration) })),
    memory: performance.memory ? {
      usedJSHeapSize: Math.round(performance.memory.usedJSHeapSize / 1048576),
      totalJSHeapSize: Math.round(performance.memory.totalJSHeapSize / 1048576)
    } : null
  });
}
```

### 3f. Layout & responsiveness
Use `browser_evaluate` to check for layout issues:
```javascript
() => {
  const body = document.body;
  const html = document.documentElement;
  const hasHorizontalScroll = body.scrollWidth > html.clientWidth;
  const overflowElements = [];
  document.querySelectorAll('*').forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.right > html.clientWidth + 5) {
      overflowElements.push({ tag: el.tagName, class: el.className, right: Math.round(rect.right) });
    }
  });
  return JSON.stringify({ hasHorizontalScroll, overflowElements: overflowElements.slice(0, 10) });
}
```

### 3g. Mobile viewport check
- `browser_resize` to 375x812 (iPhone viewport)
- `browser_take_screenshot` — mobile view
- `browser_resize` back to 1280x720

## Step 4: Execute critical journeys

Read `scripts/critical-journeys.json` and execute each journey:

For each journey:
1. `browser_navigate` to the start URL
2. For each step in the journey:
   - Execute the action (`navigate`, `click`, `fill`, `select`, `wait`, `assert_url`, `assert_text`)
   - `browser_take_screenshot` after each step
   - `browser_console_messages` — check for new errors
   - Track elapsed time
3. After all steps:
   - `browser_network_requests` — check for failures
   - Compare total journey time against `max_duration_ms`

### Journey action mapping to Playwright MCP:
| Journey action | Playwright MCP tool |
|---|---|
| `navigate` | `browser_navigate` |
| `click` | `browser_click` (use `browser_snapshot` first to find ref) |
| `fill` | `browser_fill_form` |
| `select` | `browser_select_option` |
| `wait` | `browser_wait_for` |
| `assert_url` | `browser_evaluate` to check `window.location` |
| `assert_text` | `browser_snapshot` and search for text |
| `screenshot` | `browser_take_screenshot` |
| `press_key` | `browser_press_key` |

## Step 5: Report

### Per-page report:
```
### [Page URL]
- **Status**: OK | WARN | FAIL
- **Load time**: [ms]
- **Console errors**: [count] — [details]
- **Failed requests**: [count] — [details]
- **Slow resources**: [list with durations]
- **Accessibility**: [issues found]
- **Mobile**: OK | issues
- **Screenshot**: [taken]
```

### Per-journey report:
```
### Journey: [name]
- **Status**: PASS | FAIL
- **Total time**: [ms] (limit: [max_duration_ms])
- **Steps**: [passed]/[total]
- **Failed step**: [if any — step name + screenshot + error]
- **Network errors during journey**: [list]
```

### Summary:
```
## Browser Inspection Summary
- **Pages inspected**: [count]
- **Journeys executed**: [count]
- **Issues found**: [blocker/major/minor counts]
- **Overall**: HEALTHY | DEGRADED | BROKEN
```

If issues found, include file locations and suggested fixes where possible.
