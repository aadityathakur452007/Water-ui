# Water Backend (Bun + Hono + SQLite)

Implements `Feature_docs/fullstack-contract.md` exactly. Raw SQL from
`schema.sql` (D1-portable, no ORM). Passwords: `Bun.password` argon2id.
Tokens: `node:crypto` hex Bearer tokens, 30-day expiry in `sessions`.
No bcrypt package, no extra runtime deps (only `hono`).

## Run

```bash
cd backend
bun install
bun run seed.ts        # optional: app also seeds on first boot
bun run src/index.ts   # PORT=3000, DB_PATH=./water.db by default
```

Or from the repo root (persisted volume):

```bash
docker compose up
# API on http://localhost:3000, SQLite file lives in the `water-data` volume.
```

## Seed credentials

One vendor is seeded on first boot only:

- phone: `9000000001`
- password: `Vendor@123`
- role: `vendor`

Registering via `POST /api/auth/register` always creates role `user`
(any client-supplied role is ignored).

## Endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/` | no | health `{ok:true}` |
| POST | `/api/auth/register` | no | `{name,phone,email,password}` → 201 `{token,user}` |
| POST | `/api/auth/login` | no | `{phone\|email,password}` → `{token,user}` |
| GET | `/api/products` | no | full catalog |
| GET | `/api/products/search?q=` | no | multi-word match on name/capacity/type |
| GET/POST | `/api/addresses` | user | own addresses |
| POST | `/api/orders` | user | `{items:[{productId,qty}], addressId\|address, type, slot}` → 201, status `scheduled` |
| GET | `/api/orders` | user | own orders, newest first |
| PATCH | `/api/orders/:id/cancel` | user | own order, only when `scheduled` |
| GET | `/api/vendor/orders?status=` | vendor | stripped list (no user PII) |
| PATCH | `/api/vendor/orders/:id` | vendor | `{status}`: `scheduled→preparing→out_for_delivery→delivered`, any→`cancelled` |
| GET | `/api/vendor/kpis` | vendor | `{todayDeliveries, todayRevenue, activeSubscriptions, pendingOrders}` |
| GET | `/api/vendor/subscriptions` | vendor | stripped (no user PII) |

Errors are uniform: `{error:{code,message}}` with codes
`VALIDATION`, `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`
(`INTERNAL` only for unexpected 500s).

## Verify

```bash
bun install
bun run check   # tsc --noEmit
```

## D1 migration notes (Cloudflare later)

- `schema.sql` executes unchanged on D1 (plain SQLite, `IF NOT EXISTS`,
  no Bun-specific syntax).
- Only the client changes: swap the `bun:sqlite` `Database` for the D1
  binding; all queries are parameterized `?` SQL that D1 accepts.
- Auth swaps to Firebase/Clerk (drop the `sessions` table); the Hono app
  deploys to Workers as-is.
