// Bun adapter: creates the bun:sqlite DB, injects it into the portable
// Hono app (./app.ts), serves via Bun.serve. Behavior identical to before.
import { Database } from "bun:sqlite";
import { mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { seedIfEmpty } from "../seed.ts";
import { createApp, type DbClient, type Row } from "./app.ts";

// ---------- config / db ----------
const SRC_DIR = dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = join(SRC_DIR, "..");
const DB_PATH = process.env.DB_PATH ?? join(BACKEND_DIR, "water.db");
const PORT = Number(process.env.PORT ?? 3000);

mkdirSync(dirname(DB_PATH), { recursive: true });
const db = new Database(DB_PATH);
db.exec("PRAGMA journal_mode = WAL;");
db.exec("PRAGMA foreign_keys = ON;");
db.exec(readFileSync(join(BACKEND_DIR, "schema.sql"), "utf8"));
// Migration: skip_next flag added after the initial schema (idempotent;
// plain ALTER is D1-portable).
const subCols = (db.query("PRAGMA table_info(subscriptions)").all() as Row[]).map((c) => c.name);
if (!subCols.includes("skip_next")) {
  db.exec("ALTER TABLE subscriptions ADD COLUMN skip_next INTEGER NOT NULL DEFAULT 0");
}
// Migration 0002: optional delivery days (nullable TEXT, wire key `days`).
if (!subCols.includes("days")) {
  db.exec("ALTER TABLE subscriptions ADD COLUMN days TEXT");
}
// Migration 0003_addresses: extended address columns (idempotent;
// plain ALTER is D1-portable; mirrors backend/migrations/0003_addresses.sql).
const addrCols = (db.query("PRAGMA table_info(addresses)").all() as Row[]).map((c) => c.name);
for (const [col, type] of [
  ["house", "TEXT"],
  ["street", "TEXT"],
  ["area", "TEXT"],
  ["pincode", "TEXT"],
  ["phone", "TEXT"],
  ["lat", "REAL"],
  ["lng", "REAL"],
] as const) {
  if (!addrCols.includes(col)) {
    db.exec(`ALTER TABLE addresses ADD COLUMN ${col} ${type}`);
  }
}
// Migration 0004_vendor_profile: 4 new tables (idempotent; CREATE TABLE
// IF NOT EXISTS is D1-portable; mirrors backend/migrations/0004_vendor_profile.sql).
const existingTables = new Set(
  (db.query("SELECT name FROM sqlite_master WHERE type = 'table'").all() as Row[]).map((r) => r.name as string)
);
if (!existingTables.has("vendor_profile")) {
  db.exec("CREATE TABLE IF NOT EXISTS vendor_profile (user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, name TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '', hours TEXT NOT NULL DEFAULT '')");
}
if (!existingTables.has("vendor_slots")) {
  db.exec("CREATE TABLE IF NOT EXISTS vendor_slots (user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, slot_key TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (user_id, slot_key))");
}
if (!existingTables.has("support_tickets")) {
  db.exec("CREATE TABLE IF NOT EXISTS support_tickets (id INTEGER PRIMARY KEY AUTOINCREMENT, vendor_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, subject TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at TEXT NOT NULL)");
}
if (!existingTables.has("ticket_replies")) {
  db.exec("CREATE TABLE IF NOT EXISTS ticket_replies (id INTEGER PRIMARY KEY AUTOINCREMENT, ticket_id INTEGER NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE, author TEXT NOT NULL DEFAULT 'vendor', body TEXT NOT NULL, created_at TEXT NOT NULL)");
}
await seedIfEmpty(db);

// ---------- Bun-backed DbClient (async wrappers over sync bun:sqlite) ----------
const bunDb: DbClient = {
  all: async (sql: string, ...params: any[]): Promise<Row[]> =>
    db.query(sql).all(...params) as Row[],
  one: async (sql: string, ...params: any[]): Promise<Row | null> =>
    (db.query(sql).get(...params) as Row | null) ?? null,
  run: async (sql: string, ...params: any[]) => db.query(sql).run(...params),
};

const app = createApp(bunDb, {
  hashPassword: (pw: string) => Bun.password.hash(pw, { algorithm: "argon2id" }),
  verifyPassword: (pw: string, hash: string) => Bun.password.verify(pw, hash),
});

// ---------- boot (explicit serve; no default export so Bun doesn't auto-serve twice) ----------
Bun.serve({ port: PORT, fetch: app.fetch });
console.log(`API listening on http://localhost:${PORT} (DB: ${DB_PATH})`);
