-- D1 seed — same catalog + vendor user as backend/seed.ts.
-- Runnable via: wrangler d1 execute DB --file=./seed.d1.sql
-- Idempotent (INSERT OR IGNORE). Vendor password is `Vendor@123`
-- (PBKDF2-SHA256 hash, workerd-compatible; Bun uses argon2id locally,
-- so hashes are per-env — each env seeds its own vendor row).
INSERT OR IGNORE INTO products (id, name, capacity, unit, container, water_type, price, image, available) VALUES
  ('wd-20l', '20L Drinking Water Jar', '20 Litres', 'jar', 'Reusable Water Jar', 'Drinking Water', 60, 'assets/images/jar_20l.jpg', 1),
  ('wd-15l', '15L Drinking Water Can', '15 Litres', 'can', 'Reusable Water Can', 'Drinking Water', 50, 'assets/images/jar_20l.jpg', 1),
  ('wd-10l', '10L Drinking Water Can', '10 Litres', 'can', 'Reusable Water Can', 'Drinking Water', 40, 'assets/images/jar_20l.jpg', 1),
  ('wd-1l-12', '1L Bottles · Pack of 12', '12 × 1 Litre', 'pack', 'PET Bottles', 'Drinking Water', 120, 'assets/images/bottle_1l.png', 1),
  ('wd-500ml-12', '500ml Bottles · Pack of 12', '12 × 500 ml', 'pack', 'PET Bottles', 'Drinking Water', 90, 'assets/images/bottle_1l.png', 1),
  ('wd-5l', '5L Drinking Water Can', '5 Litres', 'can', 'Reusable Water Can', 'Drinking Water', 35, 'assets/images/jar_20l.jpg', 1);

INSERT OR IGNORE INTO users (id, name, phone, email, password_hash, role, created_at) VALUES
  (1, 'Vendor', '9000000001', 'vendor@water.local', 'pbkdf2$100000$CFk08T5epQ+KPhn3RSUi1w==$PgyLUeXmD4ki+Dk4U7Zgmrmu+AXjsmZH0h68QtLpS6M=', 'vendor', '2026-09-25T00:00:00.000Z');
