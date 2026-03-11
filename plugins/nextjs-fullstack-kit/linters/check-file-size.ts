/**
 * Custom linter: No source file > 400 lines.
 *
 * Usage: npx tsx linters/check-file-size.ts
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
  const content = readFileSync(file, "utf-8");
  const lineCount = content.split("\n").length;

  if (lineCount > 400) {
    const rel = relative(process.cwd(), file);
    console.error(`  ${rel}: ${lineCount} lines (max 400)`);
    console.error(
      `    FIX: Split this file into smaller modules. Extract related functions into separate files within the same directory. If it's a component, break it into sub-components.\n`
    );
    violations++;
  }
}

if (violations > 0) {
  console.error(`\n❌ ${violations} file(s) exceed 400 lines.`);
  process.exit(1);
} else {
  console.log("✅ All files within size limit.");
}
