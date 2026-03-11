/**
 * Custom linter: No bare console.log in src/.
 * Agent-legible error messages tell exactly how to fix.
 * Add `// lint-allow-console` to a line to suppress (e.g. Edge Runtime).
 *
 * Usage: npx tsx linters/check-console-log.ts
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

function walkDir(dir: string): string[] {
  const files: string[] = [];
  try {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (entry === "node_modules" || entry === ".next") continue;
      if (statSync(full).isDirectory()) {
        files.push(...walkDir(full));
      } else if (full.endsWith(".ts") || full.endsWith(".tsx")) {
        files.push(full);
      }
    }
  } catch {
    // dir doesn't exist
  }
  return files;
}

const srcDir = join(process.cwd(), "src");
const files = walkDir(srcDir);
let violations = 0;

for (const file of files) {
  // Skip the logger itself
  if (file.endsWith("/lib/logger.ts") || file.endsWith("/logger.ts")) continue;

  const content = readFileSync(file, "utf-8");
  const lines = content.split("\n");

  lines.forEach((line, i) => {
    // Allow lines with explicit lint-disable comment
    if (line.includes("// lint-allow-console")) return;
    if (line.match(/console\.(log|warn|error|info|debug)\s*\(/)) {
      const rel = relative(process.cwd(), file);
      console.error(`  ${rel}:${i + 1}: ${line.trim()}`);
      console.error(
        `    FIX: Replace with structured logger. Import { logger } from "@/lib/logger" and use logger.info(), logger.error(), etc.\n`
      );
      violations++;
    }
  });
}

if (violations > 0) {
  console.error(`\n❌ ${violations} console.log violation(s) found.`);
  console.error(
    `Use the structured logger from src/lib/logger.ts instead. It outputs JSON for Vercel runtime logs.\n`
  );
  process.exit(1);
} else {
  console.log("✅ No console.log violations found.");
}
