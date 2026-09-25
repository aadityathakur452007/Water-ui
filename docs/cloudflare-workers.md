# Cloudflare Workers + D1 — from-scratch launch guide

Deploys the SAME Hono API from `backend/src/app.ts` to Cloudflare Workers
(workerd) with a D1 (SQLite-compatible) database. No route or response-shape
changes vs local Docker; only the adapter changes (`bun:sqlite` → D1 binding).

## (a) How the pieces talk

```
Flutter app --HTTPS--> https://<your-worker>.<account>.workers.dev
  --> Hono on workerd (backend/src/worker.ts)
  --> D1 binding `env.DB` (SQLite-compatible SQL, same schema)
```

- **Auth unchanged:** `Authorization: Bearer <hex>` 30-day tokens in the
  `sessions` table. Register/login responses are identical locally and on
  Workers.
- **API base:** Flutter reads `API_BASE_URL` via
  `--dart-define API_BASE_URL=<url>` (contract default
  `http://localhost:3000`; Android emulator `http://10.0.2.2:3000`).
- **CORS:** `app.use("*", cors())` in `app.ts` — open CORS like local dev.
  Tighten to your app origin in `app.ts` if you ship to production.
- **Passwords:** Bun locally uses argon2id (`Bun.password`); Workers uses
  WebCrypto PBKDF2-SHA256 (`backend/src/worker.ts`). Each env seeds its own
  vendor row with its own hasher, so hashes are per-env (see `seed.d1.sql`).
- **Vendor identity (2026-09-25 amendment):** `GET /api/vendor/orders` rows
  and `PATCH /api/vendor/orders/:id` responses include nested
  `customer: {name, phone, email}` (LEFT JOIN users, null-safe). Flutter
  parses tolerantly (`customer` may be `null` for guest/legacy rows).
- **Code map:**
  - `backend/src/app.ts` — portable routes (no `bun:sqlite`, no `Bun.*`).
  - `backend/src/index.ts` — Bun adapter (local/Docker).
  - `backend/src/worker.ts` — Workers adapter (`env.DB` D1).
  - `backend/wrangler.toml` — worker name, D1 binding.
  - `backend/migrations/0001_schema.sql` — D1 schema.
  - `backend/seed.d1.sql` — D1 catalog + vendor seed.

## (b) Prerequisites

1. A Cloudflare account (sign up at https://dash.cloudflare.com/sign-up,
   verify email; no zone/domain needed — `workers.dev` subdomain is enough).
2. Bun (already used locally) and Node/npm for wrangler, OR just `npx`.
3. This repo checked out on branch `feature/water-workers-demo`, with
   `backend/` changes present.

## (c) Commands in order (run from `backend/`)

```bash
cd backend

# 1. Wrangler (global install OR npx — prefer npx, no new deps)
npm i -g wrangler
# ..or: npx wrangler --version

# 2. Log in (browser OAuth; account-bound — YOU run this)
wrangler login
wrangler whoami   # should show your account

# 3. Create the D1 database (account-bound — YOU run this)
wrangler d1 create water-delivery-db
# → prints a database_id. Paste it into wrangler.toml:
#   [[d1_databases]] database_id = "<paste-here>"

# 4. Apply schema (remote)
wrangler d1 execute water-delivery-db --remote --file=./migrations/0001_schema.sql

# 5. Seed catalog + vendor (remote; idempotent INSERT OR IGNORE)
wrangler d1 execute water-delivery-db --remote --file=./seed.d1.sql

# 6. Secrets — NONE required.
# Auth is Bearer hex tokens stored as `sessions` DB rows, not env secrets.
# So no `wrangler secret put` step. If a future revision adds signing keys,
# add them here with `wrangler secret put <NAME>`.

# 7. Deploy (script already in backend/package.json: "deploy": "wrangler deploy")
npm run deploy
# ..or: npx wrangler deploy
# → prints your worker URL, e.g.
#   https://water-delivery-api.<account>.workers.dev
```

## (d) Point the app at the Worker

```bash
# From the repo root — customer app (vendor app uses the same flag):
flutter run --dart-define API_BASE_URL=https://water-delivery-api.<account>.workers.dev --dart-define DEMO_MODE=false

# Release / rebuild example:
flutter build apk --dart-define API_BASE_URL=https://water-delivery-api.<account>.workers.dev --dart-define DEMO_MODE=false
```

Replace the host with the exact URL `wrangler deploy` printed.

## (e) Verify checklist (against the Worker URL)

```bash
export API=https://water-delivery-api.<account>.workers.dev

# health
curl $API/

# register a customer
curl -s -X POST $API/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Demo User","phone":"9111111111","email":"demo@water.local","password":"Demo@123"}'
# → {"token":"...","user":{...}} — save TOKEN_USER

# catalog (public)
curl -s $API/api/products | head -c 300

# place an order as the user (inline address)
curl -s -X POST $API/api/orders \
  -H "Authorization: Bearer $TOKEN_USER" -H 'Content-Type: application/json' \
  -d '{"items":[{"productId":"wd-20l","qty":1}],"address":{"label":"home","line":"1 Main St","city":"Pune"},"type":"one-time","slot":"morning"}'

# vendor login (seeded vendor@123)
curl -s -X POST $API/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"9000000001","password":"Vendor@123"}'
# → save TOKEN_VENDOR

# vendor orders MUST include nested customer identity (list + detail proof)
curl -s $API/api/vendor/orders -H "Authorization: Bearer $TOKEN_VENDOR" | head -c 800
# expect: [{"id":..,"customer":{"name":"Demo User","phone":"9111111111","email":"demo@water.local"},...}]

# vendor transition (detail also carries customer)
curl -s -X PATCH $API/api/vendor/orders/1 \
  -H "Authorization: Bearer $TOKEN_VENDOR" -H 'Content-Type: application/json' \
  -d '{"status":"preparing"}'

# KPIs + subscriptions still work
curl -s $API/api/vendor/kpis -H "Authorization: Bearer $TOKEN_VENDOR"
curl -s $API/api/vendor/subscriptions -H "Authorization: Bearer $TOKEN_VENDOR"
```

Pass = 200s everywhere, vendor payloads show `customer.name/phone/email`,
KPIs shape `{todayDeliveries, todayRevenue, activeSubscriptions,
pendingOrders}`.

## (f) Rollback / undeploy + logs

```bash
# live logs (separate terminal, then hit the API)
wrangler tail

# rollback = redeploy a previous version (Workers keeps versions):
wrangler rollback
# ..or: wrangler versions list  →  wrangler rollback <version-id>

# undeploy / disable (pick one):
wrangler delete water-delivery-api   # deletes the worker (D1 data stays)
# D1 data is untouched by worker deletes. To wipe data (DANGEROUS):
# wrangler d1 execute water-delivery-db --remote --command="DROP TABLE IF EXISTS order_items; DROP TABLE IF EXISTS orders; ..."
# then re-run the migration + seed files from §(c).
```

## (g) Local-dev parity

- `docker compose up` in the repo root still works for offline dev
  (Bun + SQLite file in the `water-data` volume, same routes).
- D1 local emulation (no network) once wrangler is installed:
  `wrangler d1 execute water-delivery-db --local --file=./migrations/0001_schema.sql`
  then `wrangler dev` (serves `src/worker.ts` with a local D1).
- Source of truth stays `backend/schema.sql`; if you change it, mirror the
  change into `backend/migrations/` as a new `0002_*.sql` (never edit
  `0001` after it has run remotely).
