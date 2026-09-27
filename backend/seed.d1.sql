-- D1 seed — same catalog + vendor user as backend/seed.ts.
-- Runnable via: wrangler d1 execute DB --file=./seed.d1.sql
-- Idempotent (INSERT OR IGNORE). Vendor password is `Vendor@123`
-- (PBKDF2-SHA256 hash, workerd-compatible; Bun uses argon2id locally,
-- so hashes are per-env — each env seeds its own vendor row).
INSERT OR IGNORE INTO products (id, name, capacity, unit, container, water_type, price, image, available) VALUES
  ('wd-20l-refill', '20L Water Refill (Own Container)', '20 Litres', 'refill', 'Your Own Container', 'Drinking Water', 28, 'assets/images/jar_20l.jpg', 1),
  ('wd-20l-jar', '20L Jar with Container', '20 Litres', 'jar', 'Jar with Tap', 'Drinking Water', 30, 'assets/images/jar_20l_container.png', 1),
  ('wd-1l', '1L Water Bottle', '1 Litre', 'bottle', 'PET Bottle', 'Drinking Water', 0, 'assets/images/bottle_1l.png', 0);

INSERT OR IGNORE INTO users (id, name, phone, email, password_hash, role, created_at) VALUES
  (1, 'Vendor', '9000000001', 'vendor@water.local', 'pbkdf2$100000$CFk08T5epQ+KPhn3RSUi1w==$PgyLUeXmD4ki+Dk4U7Zgmrmu+AXjsmZH0h68QtLpS6M=', 'vendor', '2026-09-25T00:00:00.000Z');
