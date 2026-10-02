-- D1 migration 0004 — vendor profile, slots, support tickets (Slice 1).
-- Additive only: 4 new tables, no ALTERs. Runtime guard in src/index.ts
-- mirrors these statements for local bun:sqlite (same PRAGMA pattern as 0003).
-- `wrangler d1 execute --file` compatible: no PRAGMA, plain CREATE TABLEs.
CREATE TABLE IF NOT EXISTS vendor_profile (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  hours TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS vendor_slots (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  slot_key TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, slot_key)
);

CREATE TABLE IF NOT EXISTS support_tickets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vendor_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ticket_replies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ticket_id INTEGER NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  author TEXT NOT NULL DEFAULT 'vendor',
  body TEXT NOT NULL,
  created_at TEXT NOT NULL
);
