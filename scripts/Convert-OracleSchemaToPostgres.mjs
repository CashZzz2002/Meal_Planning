import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const repositoryRoot = path.resolve(import.meta.dirname, "..");
const sourcePath = path.join(repositoryRoot, "Database", "Oracle", "001_schema.sql");
const outputDirectory = path.join(repositoryRoot, "Database", "PostgreSql");

const source = await readFile(sourcePath, "utf8");
const sourceHash = createHash("sha256").update(source).digest("hex").toUpperCase();
const expectedHash = "7E781F7AF6EF68597314C7E7953D304F3C5827155F3F586DAF180BC50E549DF3";

if (sourceHash !== expectedHash) {
  throw new Error(`Oracle source changed (${sourceHash}). Review the conversion before regenerating PostgreSQL SQL.`);
}

let currentTable = null;
let primaryKeyCount = 0;
const convertedLines = [];

for (const originalLine of source.split(/\r?\n/)) {
  if (/^(SET DEFINE|WHENEVER SQLERROR|PROMPT )/.test(originalLine)) continue;

  const tableMatch = originalLine.match(/^CREATE TABLE "([^"]+)" \($/);
  if (tableMatch) currentTable = tableMatch[1];

  let line = originalLine
    .replace(/RAW\(16\)/g, "UUID")
    .replace(/VARCHAR2\((\d+) CHAR\)/g, "VARCHAR($1)")
    .replace(/CHAR\((\d+) CHAR\)/g, "CHAR($1)")
    .replace(/NUMBER\((\d+),(\d+)\)/g, "NUMERIC($1,$2)")
    .replace(/TIMESTAMP\(6\)/g, "TIMESTAMPTZ(6)")
    .replace(/\bCLOB\b/g, "TEXT")
    .replace(/ IS JSON STRICT/g, " IS JSON")
    .replace(/ IN \(0, 1\)/g, " IN (FALSE, TRUE)");

  if (line.includes("NUMERIC(1,0)")) line = line.replace("NUMERIC(1,0)", "BOOLEAN");

  if (currentTable && /^  CONSTRAINT "UK_[^"]+" UNIQUE \("ID"\),?$/.test(line)) {
    const suffix = line.endsWith(",") ? "," : "";
    line = `  CONSTRAINT "PK_${currentTable}" PRIMARY KEY ("ID")${suffix}`;
    primaryKeyCount += 1;
  }

  convertedLines.push(line);
  if (originalLine === ");") currentTable = null;
}

if (primaryKeyCount !== 69) {
  throw new Error(`Expected 69 primary keys, converted ${primaryKeyCount}.`);
}

let schema = convertedLines.join("\n");
const jsonColumns = [
  "BOUNDARY_GEOJSON", "BEFORE_JSON", "AFTER_JSON", "CONSTRAINTS_JSON",
  "PARAMETERS_JSON", "DIETARY_SNAPSHOT", "NUTRITION_SNAPSHOT",
  "ADDRESS_SNAPSHOT", "DELIVERY_SLOT_SNAPSHOT", "REQUESTED_CHANGES",
  "SANITIZED_PAYLOAD",
];

for (const column of jsonColumns) {
  schema = schema.replace(new RegExp(`("${column}"\\s+)TEXT`, "g"), "$1JSONB");
}

const foreignKeys = [...schema.matchAll(
  /ALTER TABLE "([^"]+)" ADD CONSTRAINT "([^"]+)"\s+FOREIGN KEY \(([^)]+)\)/g,
)];

if (foreignKeys.length !== 128) {
  throw new Error(`Expected 128 foreign keys, found ${foreignKeys.length}.`);
}

const indexStatements = foreignKeys.map((match) => {
  const [, table, constraint, columns] = match;
  const indexName = constraint.replace(/^FK_/, "IX_");
  return `CREATE INDEX "${indexName}" ON "${table}" (${columns});`;
});

const header = `-- PostgreSQL 18 conversion of the supplied Oracle 19c schema.\n` +
  `-- Source SHA-256: ${sourceHash}\n` +
  `-- Preserves quoted identifiers, 69 tables, relationships, precision and uniqueness.\n` +
  `-- PostgreSQL DDL is transactional; the whole schema rolls back on failure.\n\n` +
  `BEGIN;\nSET LOCAL TIME ZONE 'Asia/Yangon';\n\n`;

const footer = `\n\nCOMMIT;\n`;
schema = schema
  .replace(/^-- Meal planner schema:[\s\S]*?-- DDL commits implicitly\. On error, earlier successful DDL remains applied\.\r?\n\r?\n/, "")
  .trim();

const settings = `-- Keep every new database session's display/input timezone in Myanmar local time.\n` +
  `DO $$\n` +
  `BEGIN\n` +
  `  EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'Asia/Yangon');\n` +
  `  EXECUTE format('ALTER ROLE %I SET timezone TO %L', current_user, 'Asia/Yangon');\n` +
  `END\n` +
  `$$;\n`;

const indexes = `-- Index every foreign-key column list to protect join and delete/update performance.\n` +
  `BEGIN;\n${indexStatements.join("\n")}\nCOMMIT;\n`;

const seeds = `-- Stable reference data. Safe to run more than once.\n` +
`BEGIN;\n` +
`SET LOCAL TIME ZONE 'Asia/Yangon';\n\n` +
`INSERT INTO "MENUS" ("ID", "PARENT_MENU_ID", "CODE", "LABEL", "ROUTE", "SORT_ORDER", "IS_ACTIVE") VALUES\n` +
`  ('10000000-0000-0000-0000-000000000001', NULL, 'IAM', 'အသုံးပြုသူနှင့် ခွင့်ပြုချက်', '/identity', 10, TRUE),\n` +
`  ('10000000-0000-0000-0000-000000000002', NULL, 'SETUP', 'အခြေခံအချက်အလက်', '/setup', 20, TRUE),\n` +
`  ('10000000-0000-0000-0000-000000000003', NULL, 'WAREHOUSE', 'ကုန်လှောင်ရုံ', '/warehouse', 30, TRUE),\n` +
`  ('10000000-0000-0000-0000-000000000004', NULL, 'MEAL_PLAN', 'တစ်ပတ်စာဟင်းလျာ', '/meal-plans', 40, TRUE),\n` +
`  ('10000000-0000-0000-0000-000000000005', NULL, 'ORDER', 'အော်ဒါများ', '/orders', 50, TRUE)\n` +
`ON CONFLICT ("CODE") DO NOTHING;\n\n` +
`INSERT INTO "UNITS" ("ID", "CODE", "NAME_MM", "DIMENSION", "IS_ACTIVE") VALUES\n` +
`  ('20000000-0000-0000-0000-000000000001', 'G', 'ဂရမ်', 'MASS', TRUE),\n` +
`  ('20000000-0000-0000-0000-000000000002', 'KG', 'ကီလိုဂရမ်', 'MASS', TRUE),\n` +
`  ('20000000-0000-0000-0000-000000000003', 'ML', 'မီလီလီတာ', 'VOLUME', TRUE),\n` +
`  ('20000000-0000-0000-0000-000000000004', 'L', 'လီတာ', 'VOLUME', TRUE),\n` +
`  ('20000000-0000-0000-0000-000000000005', 'PCS', 'ခု', 'COUNT', TRUE)\n` +
`ON CONFLICT ("CODE") DO NOTHING;\n\n` +
`INSERT INTO "MEAL_TYPES" ("ID", "CODE", "NAME_MM", "SORT_ORDER", "IS_ACTIVE") VALUES\n` +
`  ('30000000-0000-0000-0000-000000000001', 'BREAKFAST', 'မနက်စာ', 10, TRUE),\n` +
`  ('30000000-0000-0000-0000-000000000002', 'LUNCH', 'နေ့လယ်စာ', 20, TRUE),\n` +
`  ('30000000-0000-0000-0000-000000000003', 'DINNER', 'ညစာ', 30, TRUE)\n` +
`ON CONFLICT ("CODE") DO NOTHING;\n\n` +
`INSERT INTO "PAYMENT_METHODS" ("ID", "CODE", "NAME", "IS_ENABLED") VALUES\n` +
`  ('40000000-0000-0000-0000-000000000001', 'COD', 'Cash on Delivery', TRUE),\n` +
`  ('40000000-0000-0000-0000-000000000002', 'MMQR', 'Myanmar QR', TRUE)\n` +
`ON CONFLICT ("CODE") DO NOTHING;\n\n` +
`COMMIT;\n`;

const verify = `\\pset pager off\n` +
`SET TIME ZONE 'Asia/Yangon';\n\n` +
`SELECT 'TABLES' AS metric, COUNT(*)::bigint AS value\n` +
`FROM information_schema.tables WHERE table_schema = current_schema() AND table_type = 'BASE TABLE'\n` +
`UNION ALL SELECT 'PRIMARY_KEYS', COUNT(*) FROM pg_constraint WHERE contype = 'p' AND connamespace = current_schema()::regnamespace\n` +
`UNION ALL SELECT 'FOREIGN_KEYS', COUNT(*) FROM pg_constraint WHERE contype = 'f' AND connamespace = current_schema()::regnamespace\n` +
`UNION ALL SELECT 'UNIQUE_CONSTRAINTS', COUNT(*) FROM pg_constraint WHERE contype = 'u' AND connamespace = current_schema()::regnamespace\n` +
`ORDER BY metric;\n\n` +
`SELECT current_setting('TimeZone') AS session_time_zone, CURRENT_TIMESTAMP AS current_myanmar_time;\n\n` +
`SELECT table_name AS table_without_primary_key\n` +
`FROM information_schema.tables t\n` +
`WHERE t.table_schema = current_schema() AND t.table_type = 'BASE TABLE'\n` +
`  AND NOT EXISTS (\n` +
`    SELECT 1 FROM pg_constraint c\n` +
`    WHERE c.conrelid = format('%I.%I', t.table_schema, t.table_name)::regclass\n` +
`      AND c.contype = 'p'\n` +
`  )\n` +
`ORDER BY table_name;\n\n` +
`SELECT\n` +
`  (SELECT COUNT(*) FROM "MENUS") AS menus,\n` +
`  (SELECT COUNT(*) FROM "UNITS") AS units,\n` +
`  (SELECT COUNT(*) FROM "MEAL_TYPES") AS meal_types,\n` +
`  (SELECT COUNT(*) FROM "PAYMENT_METHODS") AS payment_methods;\n`;

await mkdir(outputDirectory, { recursive: true });
await Promise.all([
  writeFile(path.join(outputDirectory, "000_database_settings.sql"), settings, "utf8"),
  writeFile(path.join(outputDirectory, "001_schema.sql"), header + schema + footer, "utf8"),
  writeFile(path.join(outputDirectory, "002_foreign_key_indexes.sql"), indexes, "utf8"),
  writeFile(path.join(outputDirectory, "003_seed_reference_data.sql"), seeds, "utf8"),
  writeFile(path.join(outputDirectory, "verify_schema.sql"), verify, "utf8"),
]);

console.log(JSON.stringify({ sourceHash, primaryKeyCount, foreignKeyCount: foreignKeys.length, outputDirectory }, null, 2));
