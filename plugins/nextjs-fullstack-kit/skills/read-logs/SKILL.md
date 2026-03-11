---
name: read-logs
description: Read and filter structured application logs. Supports per-worktree isolation, advanced jq queries, and standard filters (errors, slow queries, slow requests, vitals).
allowed-tools: Read, Grep, Glob, Bash
argument-hint: <errors|slow-queries|slow-requests|vitals|tail|query "jq expression"> [--worktree=ID]
---

# Read Application Logs

Read structured logs based on the filter: **$ARGUMENTS**

## Step 0: Resolve log file

Determine which log file to read:

1. Check if `--worktree=<ID>` flag is provided → use `.logs/<ID>/app.ndjson`
2. Check if `server-meta.json` exists in current dir → read `logFile` from it
3. Check if running in a git worktree (current dir != main worktree):
   - If yes → use `.logs/<worktree-basename>/app.ndjson`
4. Default → `.logs/app.ndjson`

To list available worktree logs:
```bash
ls -d .logs/*/app.ndjson 2>/dev/null || echo "Only main logs available"
```

## Filters

### `errors`
Find all error-level log entries:
- Use Grep to search for `"level":50` in the resolved log file
- Show the last 20 matches with context
- For each error, extract: timestamp, message, type, and any stack trace

### `slow-queries`
Find database queries slower than 100ms:
- Use Grep to search for `"type":"db"` in the resolved log file
- Filter results where `duration` > 100
- Show table name, operation, duration, and row count

### `slow-requests`
Find HTTP requests slower than 500ms:
- Use Grep to search for `"type":"http"` in the resolved log file
- Filter results where `duration` > 500
- Show method, path, status, and duration

### `vitals`
Read Web Vitals reports:
- Use Grep to search for `"type":"vital"` in the resolved log file
- Show the last 20 entries
- Group by metric name (LCP, FCP, CLS, etc.) if possible

### `tail`
Show the last 50 lines of the log file:
- Use Read tool on the resolved log file with appropriate offset
- Parse and format the JSON entries for readability

### `query "<jq expression>"`
Run an advanced jq query against the log file:
```bash
cat <LOG_FILE> | jq '<expression>' 2>&1 | tail -50
```

Example queries:
- `/read-logs query 'select(.level >= 50 and .duration > 500)'` — slow errors
- `/read-logs query 'select(.type == "db") | {table, duration, rows}'` — DB summary
- `/read-logs query 'select(.msg | test("timeout"))' ` — timeout-related entries
- `/read-logs query '[.[] | select(.type == "http")] | group_by(.path) | map({path: .[0].path, count: length, avg_ms: (map(.duration) | add / length | round)})'` — request stats by path

### `summary`
Generate a log summary across all available worktree logs:
```bash
for f in .logs/*/app.ndjson .logs/app.ndjson; do
  [ -f "$f" ] || continue
  ERRORS=$(grep -c '"level":50' "$f" 2>/dev/null || echo 0)
  LINES=$(wc -l < "$f" | tr -d ' ')
  echo "$f: $LINES entries, $ERRORS errors"
done
```

## Output Format

Present results as a table when possible:
```
| Timestamp | Type | Details | Duration |
|-----------|------|---------|----------|
| ... | db | SELECT users | 145ms |
```

If no log file exists, inform the user: "No logs found. Start the dev server with `npm run dev` to generate logs."

If multiple worktree logs exist, mention: "Tip: use `--worktree=<ID>` to read logs from a specific worktree, or `summary` to see all."
