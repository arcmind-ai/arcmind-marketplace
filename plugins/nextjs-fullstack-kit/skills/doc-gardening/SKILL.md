---
name: doc-gardening
description: Scan docs/ for stale or inaccurate documentation. Cross-reference with actual code and fix discrepancies. Run periodically to keep docs fresh.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: [optional: specific doc file or directory to check]
---

# Doc Gardening

Scan the repository documentation for staleness and accuracy.

## Check Each Doc File
For every `.md` file in `docs/`:

1. **Read the doc**
2. **Cross-reference with code**:
   - File paths mentioned — do they still exist?
   - Function/component names mentioned — are they still named that?
   - API routes described — do they match the actual route handlers?
   - DB schema described — does it match current types?
3. **Check freshness**:
   - Run `git log -1 --format="%ar" -- <file>` to see when last updated
   - If > 2 weeks old and references code that changed since, flag it

## Check CLAUDE.md
- Are the quick start commands still correct?
- Do the "Where to Look" paths exist?
- Are the key rules still enforced?

## Check ARCHITECTURE.md
- Does the directory structure match reality? (`ls src/`)
- Are the layer rules still accurate?
- Any new domains not documented?

## Fix What You Find
For each stale doc:
- Update it to match current code
- If a doc references something that no longer exists, remove that section
- If a new domain/feature exists without docs, create a stub

## Report
Produce a summary:
```
### Doc Gardening Report
- Files checked: N
- Files up-to-date: N
- Files updated: N
- Files flagged for human review: N
- Details: [list of changes made]
```
