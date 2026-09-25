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
  { id: "wd-20l", name: "20L Drinking Water Jar", capacity: "20 Litres", unit: "jar", container: "Reusable Water Jar", water_type: "Drinking Water", price: 60, image: "assets/icons/water_jar.svg" },
  { id: "wd-15l", name: "15L Drinking Water Can", capacity: "15 Litres", unit: "can", container: "Reusable Water Can", water_type: "Drinking Water", price: 50, image: "assets/icons/water_jar.svg" },
  { id: "wd-10l", name: "10L Drinking Water Can", capacity: "10 Litres", unit: "can", container: "Reusable Water Can", water_type: "Drinking Water", price: 40, image: "assets/icons/water_jar.svg" },
  { id: "wd-1l-12", name: "1L Bottles · Pack of 12", capacity: "12 × 1 Litre", unit: "pack", container: "PET Bottles", water_type: "Drinking Water", price: 120, image: "assets/icons/water_bottle.svg" },
  { id: "wd-500ml-12", name: "500ml Bottles · Pack of 12", capacity: "12 × 500 ml", unit: "pack", container: "PET Bottles", water_type: "Drinking Water", price: 90, image: "assets/icons/water_bottle.svg" },
  { id: "wd-5l", name: "5L Drinking Water Can", capacity: "5 Litres", unit: "can", container: "Reusable Water Can", water_type: "Drinking Water", price: 35, image: "assets/icons/water_jar.svg" },
];

export async function seedIfEmpty(db: Database): Promise<void> {
  const pCount = (db.query("SELECT COUNT(*) AS n FROM products").get() as any).n as number;
  if (pCount === 0) {
    const insertProduct = db.query(
      "INSERT INTO products (id, name, capacity, unit, container, water_type, price, image, available) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)"
    );
    const insertAll = db.transaction(() => {
      for (const p of PRODUCTS) {
        insertProduct.run(p.id, p.name, p.capacity, p.unit, p.container, p.water_type, p.price, p.image);
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
