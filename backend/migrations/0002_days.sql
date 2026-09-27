-- D1 migration 0002 — optional delivery days on subscriptions.
-- Nullable TEXT wire key `days`, e.g. "Mon,Wed,Fri".
ALTER TABLE subscriptions ADD COLUMN days TEXT;
