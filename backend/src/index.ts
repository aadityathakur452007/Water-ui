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
