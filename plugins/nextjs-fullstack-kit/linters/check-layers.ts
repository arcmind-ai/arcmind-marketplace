/**
 * Custom linter: Enforce domain layer dependency rules.
 *
 * Layers (in order): types.ts → db.ts → service.ts → API route → UI component
 * Dependencies can only flow forward. Violations get agent-legible error messages.
 *
 * Usage: npx tsx linters/check-layers.ts
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

const LAYER_ORDER = ["types", "db", "service", "route", "component"] as const;
type Layer = (typeof LAYER_ORDER)[number];

function getLayer(filePath: string): Layer | null {
  const rel = relative(process.cwd(), filePath);
  if (rel.includes("types.ts")) return "types";
  if (rel.includes("db.ts")) return "db";
  if (rel.includes("service.ts")) return "service";
  if (rel.includes("app/api/")) return "route";
  if (rel.includes("components/") || rel.endsWith(".tsx")) return "component";
  return null;
}

function layerIndex(layer: Layer): number {
  return LAYER_ORDER.indexOf(layer);
}

interface Violation {
  file: string;
  line: number;
  fromLayer: Layer;
  toLayer: Layer;
  importPath: string;
  fix: string;
}

function checkFile(filePath: string): Violation[] {
  const violations: Violation[] = [];
  const fromLayer = getLayer(filePath);
  if (!fromLayer) return violations;

  const content = readFileSync(filePath, "utf-8");
  const lines = content.split("\n");

  lines.forEach((line, i) => {
    const match = line.match(/from\s+["']([^"']+)["']/);
    if (!match) return;

    const importPath = match[1];
    if (!importPath.startsWith(".") && !importPath.startsWith("@/")) return;

    let toLayer: Layer | null = null;
    if (importPath.includes("/db")) toLayer = "db";
    else if (importPath.includes("/service")) toLayer = "service";
    else if (importPath.includes("/types")) toLayer = "types";

    if (!toLayer) return;

    const fromIdx = layerIndex(fromLayer);
    const toIdx = layerIndex(toLayer);

    // Layer order: types(0) → db(1) → service(2) → route(3) → component(4)
    // Dependencies flow forward: higher layers import from lower layers.
    // A file can only import from layers with LOWER or EQUAL index.
    //   db(1) importing types(0) → toIdx(0) <= fromIdx(1) → OK
    //   types(0) importing db(1) → toIdx(1) > fromIdx(0) → VIOLATION
    //   component(4) importing service(2) → toIdx(2) <= fromIdx(4) → OK
    //   service(2) importing route(3) → toIdx(3) > fromIdx(2) → VIOLATION
    if (toIdx <= fromIdx) return; // importing from same or lower layer = OK

    // VIOLATION: importing from a higher layer
    let fix = "";
    if (fromLayer === "types" && toLayer === "db") {
      fix = `types.ts must not import db.ts. Move shared types to types.ts and import them from there in db.ts.`;
    } else if (fromLayer === "types" && toLayer === "service") {
      fix = `types.ts must not import service.ts. Types should be self-contained with no domain logic dependencies.`;
    } else if (fromLayer === "db" && toLayer === "service") {
      fix = `db.ts must not import service.ts. The service layer calls db, not the other way around. If db needs a type from service, move that type to types.ts.`;
    } else if (fromLayer === "service" && toLayer === "route") {
      fix = `service.ts must not import API routes. Routes call services, not the other way around. If you need shared logic, extract it to service.ts.`;
    } else if (fromLayer === "route" && toLayer === "component") {
      fix = `API routes must not import UI components. Routes return data, components consume it.`;
    } else {
      fix = `${fromLayer} layer (index ${fromIdx}) must not import from ${toLayer} layer (index ${toIdx}). Dependencies must flow: Types → DB → Service → Route → Component. Lower layers cannot depend on higher layers.`;
    }

    violations.push({
      file: relative(process.cwd(), filePath),
      line: i + 1,
      fromLayer,
      toLayer,
      importPath,
      fix,
    });
  });

  return violations;
}

function walkDir(dir: string, ext: string[]): string[] {
  const files: string[] = [];
  try {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (entry === "node_modules" || entry === ".next") continue;
      if (statSync(full).isDirectory()) {
        files.push(...walkDir(full, ext));
      } else if (ext.some((e) => full.endsWith(e))) {
        files.push(full);
      }
    }
  } catch {
    // directory doesn't exist yet
  }
  return files;
}

const srcDir = join(process.cwd(), "src");
const files = walkDir(srcDir, [".ts", ".tsx"]);
const allViolations: Violation[] = [];

for (const file of files) {
  allViolations.push(...checkFile(file));
}

if (allViolations.length > 0) {
  console.error(`\n❌ ${allViolations.length} layer violation(s) found:\n`);
  for (const v of allViolations) {
    console.error(`  ${v.file}:${v.line}`);
    console.error(`    ${v.fromLayer} → ${v.toLayer} (import "${v.importPath}")`);
    console.error(`    FIX: ${v.fix}\n`);
  }
  process.exit(1);
} else {
  console.log("✅ No layer violations found.");
}
