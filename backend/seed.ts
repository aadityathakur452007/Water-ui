// Seed script + shared seed-if-empty helper (imported by src/index.ts).
// Run manually with: bun run seed.ts
// Idempotent: inserts the 6 catalog products only if the table is empty,
// and the single vendor account only if no vendor exists yet.
import { Database } from "bun:sqlite";
import { mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_DB = join(HERE, "water.db");

export const VENDOR_PHONE = "9000000001";
export const VENDOR_PASSWORD = "Vendor@123";

const PRODUCTS = [
  { id: "wd-20l-refill", name: "20L Water Refill (Own Container)", capacity: "20 Litres", unit: "refill", container: "Your Own Container", water_type: "Drinking Water", price: 28, image: "assets/images/jar_20l.jpg", available: 1 },
  { id: "wd-20l-jar", name: "20L Jar with Container", capacity: "20 Litres", unit: "jar", container: "Jar with Tap", water_type: "Drinking Water", price: 30, image: "assets/images/jar_20l.jpg", available: 1 },
  { id: "wd-1l", name: "1L Water Bottle", capacity: "1 Litre", unit: "bottle", container: "PET Bottle", water_type: "Drinking Water", price: 0, image: "assets/images/bottle_1l.png", available: 0 },
];

export async function seedIfEmpty(db: Database): Promise<void> {
  const pCount = (db.query("SELECT COUNT(*) AS n FROM products").get() as any).n as number;
  if (pCount === 0) {
    const insertProduct = db.query(
      "INSERT INTO products (id, name, capacity, unit, container, water_type, price, image, available) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    const insertAll = db.transaction(() => {
      for (const p of PRODUCTS) {
        insertProduct.run(p.id, p.name, p.capacity, p.unit, p.container, p.water_type, p.price, p.image, p.available);
      }
    });
    insertAll();
  }
  const vendor = db.query("SELECT id FROM users WHERE role = 'vendor' LIMIT 1").get();
  if (!vendor) {
    const hash = await Bun.password.hash(VENDOR_PASSWORD, { algorithm: "argon2id" });
    db.query(
      "INSERT INTO users (name, phone, email, password_hash, role, created_at) VALUES (?, ?, ?, ?, 'vendor', ?)"
    ).run("Vendor", VENDOR_PHONE, "vendor@water.local", hash, new Date().toISOString());
  }
}

if (import.meta.main) {
  const dbPath = process.env.DB_PATH ?? DEFAULT_DB;
  mkdirSync(dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.exec("PRAGMA foreign_keys = ON;");
  db.exec(readFileSync(join(HERE, "schema.sql"), "utf8"));
  await seedIfEmpty(db);
  console.log(`Seeded ${dbPath}`);
  db.close();
}
