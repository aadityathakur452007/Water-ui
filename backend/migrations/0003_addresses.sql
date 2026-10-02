-- D1 migration 0003 — extended address columns (Agent B).
-- All nullable for back-compat: old rows keep working with `line` fallback.
-- Applied once in order (same pattern as 0002_days.sql).
ALTER TABLE addresses ADD COLUMN house TEXT;
ALTER TABLE addresses ADD COLUMN street TEXT;
ALTER TABLE addresses ADD COLUMN area TEXT;
ALTER TABLE addresses ADD COLUMN pincode TEXT;
ALTER TABLE addresses ADD COLUMN phone TEXT;
ALTER TABLE addresses ADD COLUMN lat REAL;
ALTER TABLE addresses ADD COLUMN lng REAL;
