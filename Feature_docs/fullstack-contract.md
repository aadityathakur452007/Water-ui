# Fullstack Contract (FROZEN — all agents build to this, do not renegotiate)

Monorepo: `apps/user` (customer app), `apps/vendor` (vendor app),
`backend` (Hono + TypeScript + SQLite, Bun runtime, Docker).

## Runtime / ports
- API base: `http://localhost:3000` (iOS sim, Docker host, CI).
  Android emulator uses `http://10.0.2.2:3000`.
- Flutter override: `--dart-define API_BASE_URL=<url>`.
- `docker compose up` in repo root starts the API with a persisted volume.
- DB file: SQLite (`water.db`). Schema is plain-SQLite = runs as-is on
  Cloudflare D1 later (swap `bun:sqlite` client for the D1 binding only).

## Auth
- `POST /api/auth/register` `{name,phone,email,password}` → `201 {token,user}`.
  Role is FORCED to `user` (client-supplied role ignored — ssdlc).
- `POST /api/auth/login` `{phone|email,password}` → `{token,user}`.
- `user = {id,name,phone,email,role}`. Token: `Authorization: Bearer <hex>`,
  30-day expiry, `sessions` table. Passwords: `Bun.password` argon2id.
- Seed on first boot ONLY: one vendor
  (`phone 9000000001 / password Vendor@123 / role vendor`, must change).

## Catalog / orders (user, auth required except catalog)
- `GET /api/products` → full catalog (matches Flutter seed prices).
- `GET /api/products/search?q=` → multi-word match on name/capacity/type.
- `GET+POST /api/addresses` → own addresses.
- `POST /api/orders` `{items:[{productId,qty}], addressId|address, type, slot}`
  → `201` order, status `scheduled`.
- `GET /api/orders` → own orders, newest first.
- `PATCH /api/orders/:id/cancel` → own + only when `scheduled`.

## Vendor (role=vendor required, else 403) — PII RULE (ssdlc, enforced server-side)
- AMENDED 2026-09-25 (user-approved, supersedes the old address+items-only
  rule): vendor order payloads MAY include customer identity as a nested
  `customer: {name, phone, email}` (users JOIN, null-safe — guest/legacy
  rows yield `customer: null`, never a crash; Flutter parses tolerantly).
  Rationale: vendors need to know their customers. Vendor may see:
  customer name/phone/email + order id, items (name/qty/price), totals,
  delivery address (label/line/city), slot, status, type, timestamps.
  Nothing else from `users` leaks (never password_hash/role/sessions).
- `GET /api/vendor/orders?status=` → list rows, each with nested `customer`.
- `PATCH /api/vendor/orders/:id` `{status}` → allowed transitions only:
  `scheduled→preparing→out_for_delivery→delivered`, any→`cancelled`.
  Returns the updated order detail with nested `customer`.
- `GET /api/vendor/kpis` →
  `{todayDeliveries, todayRevenue, activeSubscriptions, pendingOrders}`.
- `GET /api/vendor/subscriptions` → stripped (no user PII).

## Schema (SQLite — see backend/schema.sql as source of truth)
`users(id,name,phone!,email!,password_hash,role,created_at)`,
`sessions(token,user_id,expires_at)`, `products(id,name,capacity,unit,
container,water_type,price,image,available)`, `addresses(id,user_id,
label,line,city)`, `orders(id,user_id,address_id,type,status,total,
slot,created_at)`, `order_items(order_id,product_id,name,qty,price)`,
`subscriptions(id,user_id,product_id,quantity,frequency,start_date,
delivery_time,status,next_delivery)`.

## Errors (uniform)
`{error: {code, message}}` + HTTP status. Codes: `VALIDATION`,
`UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`.

## Migration notes (Cloudflare later)
- `schema.sql` executes unchanged on D1. Auth swaps to Firebase/Clerk
  (session table dropped); Hono app deploys to Workers as-is.
