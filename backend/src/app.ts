// Water delivery API — portable Hono app (Bun + Cloudflare Workers).
// NO `bun:sqlite` / `Bun.*` / `node:*` / fs imports here. DB access is via
// the injected DbClient; password hashing via injected AuthHasher. The same
// routes run on Bun (backend/src/index.ts) and workerd (backend/src/worker.ts).
import { Hono, type Context } from "hono";
import { cors } from "hono/cors";

// ---------- portable DB / auth contracts (Adapter pattern) ----------
export type Row = Record<string, any>;
export interface DbClient {
  all(sql: string, ...params: any[]): Promise<Row[]>;
  one(sql: string, ...params: any[]): Promise<Row | null>;
  run(sql: string, ...params: any[]): Promise<{ lastInsertRowid: number | string }>;
}
export interface AuthHasher {
  hashPassword(pw: string): Promise<string>;
  verifyPassword(pw: string, hash: string): Promise<boolean>;
}

// ---------- types / serializers ----------
export type PublicUser = { id: number; name: string; phone: string; email: string; role: string };
type Ctx = Context<{ Variables: { user: PublicUser } }>;

const err = (code: string, message: string) => ({ error: { code, message } });
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
// Server owns the flat ₹10 delivery fee (approved: client totals ignored).
const DELIVERY_FEE = 10;

const toUser = (r: Row): PublicUser => ({ id: r.id, name: r.name, phone: r.phone, email: r.email, role: r.role });
const toProduct = (r: Row) => ({
  id: r.id, name: r.name, capacity: r.capacity, unit: r.unit, container: r.container,
  water_type: r.water_type, price: r.price, image: r.image, available: Boolean(r.available),
});

function newToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let s = "";
  for (const b of bytes) s += b.toString(16).padStart(2, "0");
  return s;
}

async function createSession(db: DbClient, userId: number): Promise<string> {
  const token = newToken();
  await db.run("INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)", token, userId, Date.now() + THIRTY_DAYS_MS);
  return token;
}

async function readJson(c: Ctx): Promise<any> {
  try {
    return await c.req.json();
  } catch {
    return null;
  }
}

// Extended address columns (nullable for back-compat; old rows keep
// working with the `line` fallback).
const ADDR_COLS = "id, label, line, city, house, street, area, pincode, phone, lat, lng";
const ADDR_COLS_NO_ID = "label, line, city, house, street, area, pincode, phone, lat, lng";

// Allowlist validation for optional address fields. Returns an error
// message or null when valid. Empty/absent values are OK (back-compat).
function addressFieldError(body: any): string | null {
  const pincode = body?.pincode;
  if (pincode != null && String(pincode).trim() !== "" && !/^[1-9][0-9]{5}$/.test(String(pincode).trim())) {
    return "pincode must be a 6-digit code starting 1-9";
  }
  const phone = body?.phone;
  if (phone != null && String(phone).trim() !== "" && !/^[0-9]{10}$/.test(String(phone).trim())) {
    return "phone must be 10 digits";
  }
  for (const key of ["lat", "lng"] as const) {
    const v = body?.[key];
    if (v == null || String(v).trim() === "") continue;
    const n = Number(v);
    if (!Number.isFinite(n)) return `${key} must be a number`;
    if (key === "lat" && (n < -90 || n > 90)) return "lat must be between -90 and 90";
    if (key === "lng" && (n < -180 || n > 180)) return "lng must be between -180 and 180";
  }
  return null;
}

// Normalizes optional address fields to null-vs-value for parameterized inserts.
function addressExtras(body: any) {
  const opt = (v: any) => {
    const s = v == null ? "" : String(v).trim();
    return s === "" ? null : s;
  };
  const num = (v: any) => {
    if (v == null || String(v).trim() === "") return null;
    return Number(v);
  };
  return {
    house: opt(body?.house),
    street: opt(body?.street),
    area: opt(body?.area),
    pincode: opt(body?.pincode),
    phone: opt(body?.phone),
    lat: num(body?.lat),
    lng: num(body?.lng),
  };
}

// Response projection for an address row. Extended columns ride along
// (null for legacy rows); clients fall back to `line` when absent.
function toAddressJson(a: Row, withId: boolean) {
  const base: Row = {
    label: a.label, line: a.line, city: a.city,
    house: a.house ?? null, street: a.street ?? null, area: a.area ?? null,
    pincode: a.pincode ?? null, phone: a.phone ?? null,
    lat: a.lat ?? null, lng: a.lng ?? null,
  };
  return withId ? { id: a.id, ...base } : base;
}

// Full order view for the owning user.
async function userOrderDetail(db: DbClient, orderId: number): Promise<any> {
  const o = (await db.one("SELECT * FROM orders WHERE id = ?", orderId)) as Row;
  const items = (await db.all("SELECT product_id, name, qty, price FROM order_items WHERE order_id = ?", orderId))
    .map((i) => ({ productId: i.product_id, name: i.name, qty: i.qty, price: i.price }));
  const a = o.address_id ? await db.one(`SELECT ${ADDR_COLS} FROM addresses WHERE id = ?`, o.address_id) : null;
  return {
    id: o.id, type: o.type, status: o.status, total: o.total, slot: o.slot ?? null,
    address: a ? toAddressJson(a as Row, true) : null,
    items, created_at: o.created_at,
  };
}

// Vendor view: order + items + address + nested customer identity
// (approved 2026-09-25: vendors may see customer name/phone/email).
// LEFT JOIN users so guest/legacy rows yield customer null, never a crash.
async function vendorOrderDetail(db: DbClient, orderId: number): Promise<any> {
  const o = (await db.one(
    `SELECT o.*, u.name AS customer_name, u.phone AS customer_phone, u.email AS customer_email
     FROM orders o LEFT JOIN users u ON u.id = o.user_id WHERE o.id = ?`,
    orderId
  )) as Row;
  const items = (await db.all("SELECT product_id, name, qty, price FROM order_items WHERE order_id = ?", orderId))
    .map((i) => ({ productId: i.product_id, name: i.name, qty: i.qty, price: i.price }));
  const a = o.address_id ? await db.one(`SELECT ${ADDR_COLS_NO_ID} FROM addresses WHERE id = ?`, o.address_id) : null;
  const hasCustomer = o.customer_name != null || o.customer_phone != null || o.customer_email != null;
  return {
    id: o.id, type: o.type, status: o.status, total: o.total, slot: o.slot ?? null,
    address: a ? toAddressJson(a as Row, false) : null,
    customer: hasCustomer
      ? { name: o.customer_name ?? "", phone: o.customer_phone ?? "", email: o.customer_email ?? "" }
      : null,
    items, created_at: o.created_at,
  };
}

export function createApp(db: DbClient, auth: AuthHasher) {
  const app = new Hono<{ Variables: { user: PublicUser } }>();
  app.use("*", cors());

  app.onError((e, c) => {
    console.error(e);
    return c.json(err("INTERNAL", "Unexpected server error"), 500);
  });
  app.notFound((c) => c.json(err("NOT_FOUND", "Route not found"), 404));

  const PUBLIC_GET = new Set(["/api/products", "/api/products/search"]);
  app.use(async (c, next) => {
    const path = c.req.path;
    if (!path.startsWith("/api/")) return next();
    if (c.req.method === "GET" && PUBLIC_GET.has(path)) return next();
    if (c.req.method === "POST" && (path === "/api/auth/register" || path === "/api/auth/login")) return next();
    const header = c.req.header("authorization") ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!token) return c.json(err("UNAUTHENTICATED", "Missing bearer token"), 401);
    const sess = await db.one("SELECT user_id, expires_at FROM sessions WHERE token = ?", token);
    if (!sess || (sess.expires_at as number) < Date.now()) {
      if (sess) await db.run("DELETE FROM sessions WHERE token = ?", token);
      return c.json(err("UNAUTHENTICATED", "Invalid or expired token"), 401);
    }
    const user = await db.one("SELECT * FROM users WHERE id = ?", sess.user_id);
    if (!user) return c.json(err("UNAUTHENTICATED", "Invalid or expired token"), 401);
    c.set("user", toUser(user));
    await next();
  });

  app.use("/api/vendor/*", async (c, next) => {
    const user = c.get("user");
    if (!user || user.role !== "vendor") return c.json(err("FORBIDDEN", "Vendor role required"), 403);
    await next();
  });

  // ---------- handlers: auth ----------
  async function registerHandler(c: Ctx) {
    const body = await readJson(c);
    const name = String(body?.name ?? "").trim();
    const phone = String(body?.phone ?? "").trim();
    const email = String(body?.email ?? "").trim();
    const password = String(body?.password ?? "");
    if (!name || !phone || !email || !password) {
      return c.json(err("VALIDATION", "name, phone, email and password are required"), 400);
    }
    if (!email.includes("@")) return c.json(err("VALIDATION", "email must be valid"), 400);
    if (await db.one("SELECT id FROM users WHERE phone = ? OR email = ?", phone, email)) {
      return c.json(err("CONFLICT", "phone or email already registered"), 409);
    }
    // Role is FORCED to user: any client-supplied role is ignored.
    const hash = await auth.hashPassword(password);
    const r = await db.run(
      "INSERT INTO users (name, phone, email, password_hash, role, created_at) VALUES (?, ?, ?, ?, 'user', ?)",
      name, phone, email, hash, new Date().toISOString()
    );
    const user = toUser((await db.one("SELECT * FROM users WHERE id = ?", Number(r.lastInsertRowid))) as Row);
    const token = await createSession(db, user.id);
    return c.json({ token, user }, 201);
  }

  async function loginHandler(c: Ctx) {
    const body = await readJson(c);
    const identifier = String(body?.phone ?? body?.email ?? "").trim();
    const password = String(body?.password ?? "");
    if (!identifier || !password) return c.json(err("VALIDATION", "phone/email and password are required"), 400);
    const row = await db.one("SELECT * FROM users WHERE phone = ? OR email = ?", identifier, identifier);
    if (!row) return c.json(err("UNAUTHENTICATED", "Invalid credentials"), 401);
    const ok = await auth.verifyPassword(password, row.password_hash);
    if (!ok) return c.json(err("UNAUTHENTICATED", "Invalid credentials"), 401);
    const token = await createSession(db, row.id);
    return c.json({ token, user: toUser(row) });
  }

  // ---------- handlers: catalog / addresses / orders (user) ----------
  async function listProducts(c: Ctx) {
    return c.json((await db.all("SELECT * FROM products ORDER BY price ASC")).map(toProduct));
  }

  async function searchProducts(c: Ctx) {
    const words = String(c.req.query("q") ?? "").toLowerCase().split(/\s+/).filter(Boolean);
    if (words.length === 0) return c.json([]);
    const where = words.map(() => "(lower(name) LIKE ? OR lower(capacity) LIKE ? OR lower(water_type) LIKE ?)").join(" AND ");
    const params = words.flatMap((w) => [`%${w}%`, `%${w}%`, `%${w}%`]);
    return c.json((await db.all(`SELECT * FROM products WHERE ${where} ORDER BY price ASC`, ...params)).map(toProduct));
  }

  async function listAddresses(c: Ctx) {
    const user = c.get("user");
    return c.json(
      await db.all(`SELECT ${ADDR_COLS} FROM addresses WHERE user_id = ? ORDER BY id ASC`, user.id)
    );
  }

  async function createAddress(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const label = String(body?.label ?? "").trim();
    const line = String(body?.line ?? "").trim();
    const city = String(body?.city ?? "").trim();
    if (!label || !line || !city) return c.json(err("VALIDATION", "label, line and city are required"), 400);
    const fieldErr = addressFieldError(body);
    if (fieldErr) return c.json(err("VALIDATION", fieldErr), 400);
    const ex = addressExtras(body);
    const r = await db.run(
      "INSERT INTO addresses (user_id, label, line, city, house, street, area, pincode, phone, lat, lng) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      user.id, label, line, city, ex.house, ex.street, ex.area, ex.pincode, ex.phone, ex.lat, ex.lng
    );
    const a = (await db.one(`SELECT ${ADDR_COLS} FROM addresses WHERE id = ?`, Number(r.lastInsertRowid))) as Row;
    return c.json(a, 201);
  }

  async function createOrder(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const items = body?.items;
    if (!Array.isArray(items) || items.length === 0) {
      return c.json(err("VALIDATION", "items must be a non-empty array"), 400);
    }
    let addressId: number | null = null;
    if (body?.addressId != null) {
      const a = await db.one("SELECT id FROM addresses WHERE id = ? AND user_id = ?", Number(body.addressId), user.id);
      if (!a) return c.json(err("NOT_FOUND", "Address not found"), 404);
      addressId = a.id as number;
    } else if (body?.address && typeof body.address === "object") {
      const label = String(body.address.label ?? "").trim();
      const line = String(body.address.line ?? "").trim();
      const city = String(body.address.city ?? "").trim();
      if (!label || !line || !city) return c.json(err("VALIDATION", "address needs label, line and city"), 400);
      const fieldErr = addressFieldError(body.address);
      if (fieldErr) return c.json(err("VALIDATION", fieldErr), 400);
      const ex = addressExtras(body.address);
      const r = await db.run(
        "INSERT INTO addresses (user_id, label, line, city, house, street, area, pincode, phone, lat, lng) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        user.id, label, line, city, ex.house, ex.street, ex.area, ex.pincode, ex.phone, ex.lat, ex.lng
      );
      addressId = Number(r.lastInsertRowid);
    } else {
      return c.json(err("VALIDATION", "addressId or address is required"), 400);
    }
    const type = body?.type ?? "one-time";
    if (type !== "one-time" && type !== "regular") return c.json(err("VALIDATION", "type must be one-time or regular"), 400);
    const slot = body?.slot != null ? String(body.slot) : null;
    // Totals are computed server-side from catalog prices; client totals ignored.
    let total = 0;
    const lines: { product: Row; qty: number }[] = [];
    for (const it of items) {
      const productId = it?.productId ?? it?.product_id;
      const qty = Number(it?.qty);
      if (!productId || !Number.isInteger(qty) || qty <= 0) {
        return c.json(err("VALIDATION", "each item needs productId and a positive integer qty"), 400);
      }
      const p = await db.one("SELECT * FROM products WHERE id = ?", String(productId));
      if (!p) return c.json(err("NOT_FOUND", `Product ${productId} not found`), 404);
      if (!p.available) return c.json(err("CONFLICT", `Product ${productId} is unavailable`), 409);
      total += (p.price as number) * qty;
      lines.push({ product: p, qty });
    }
    total += DELIVERY_FEE;
    const now = new Date().toISOString();
    // D1-compatible: sequential inserts, no interactive transaction
    // (bun:sqlite adapter runs the same code; atomicity is best-effort).
    const r = await db.run(
      "INSERT INTO orders (user_id, address_id, type, status, total, slot, created_at) VALUES (?, ?, ?, 'scheduled', ?, ?, ?)",
      user.id, addressId, type, total, slot, now
    );
    const orderId = Number(r.lastInsertRowid);
    for (const l of lines) {
      await db.run("INSERT INTO order_items (order_id, product_id, name, qty, price) VALUES (?, ?, ?, ?, ?)",
        orderId, l.product.id, l.product.name, l.qty, l.product.price);
    }
    return c.json(await userOrderDetail(db, orderId), 201);
  }

  async function listOrders(c: Ctx) {
    const user = c.get("user");
    const rows = await db.all("SELECT id FROM orders WHERE user_id = ? ORDER BY id DESC", user.id);
    const out: any[] = [];
    for (const r of rows) out.push(await userOrderDetail(db, r.id));
    return c.json(out);
  }

  async function cancelOrder(c: Ctx) {
    const user = c.get("user");
    const o = await db.one("SELECT * FROM orders WHERE id = ? AND user_id = ?", Number(c.req.param("id")), user.id);
    if (!o) return c.json(err("NOT_FOUND", "Order not found"), 404);
    if (o.status !== "scheduled") return c.json(err("CONFLICT", "Only scheduled orders can be cancelled"), 409);
    await db.run("UPDATE orders SET status = 'cancelled' WHERE id = ?", o.id);
    return c.json(await userOrderDetail(db, o.id));
  }

  // ---------- handlers: vendor ----------
  const NEXT_STATUS: Record<string, string> = {
    scheduled: "preparing",
    preparing: "out_for_delivery",
    out_for_delivery: "delivered",
  };
  const KNOWN_STATUS = new Set(["scheduled", "preparing", "out_for_delivery", "delivered", "cancelled"]);

  async function vendorOrders(c: Ctx) {
    const status = c.req.query("status");
    const rows = status
      ? await db.all("SELECT id FROM orders WHERE status = ? ORDER BY id DESC", status)
      : await db.all("SELECT id FROM orders ORDER BY id DESC");
    const out: any[] = [];
    for (const r of rows) out.push(await vendorOrderDetail(db, r.id));
    return c.json(out);
  }

  async function vendorUpdateStatus(c: Ctx) {
    const body = await readJson(c);
    const target = body?.status != null ? String(body.status) : "";
    if (!KNOWN_STATUS.has(target)) return c.json(err("VALIDATION", "status must be a known order status"), 400);
    const o = await db.one("SELECT * FROM orders WHERE id = ?", Number(c.req.param("id")));
    if (!o) return c.json(err("NOT_FOUND", "Order not found"), 404);
    if (o.status === target) return c.json(err("CONFLICT", `Order is already ${target}`), 409);
    // Allowed: one step forward along scheduled->preparing->out_for_delivery->delivered, or any->cancelled.
    if (target !== "cancelled" && NEXT_STATUS[o.status as string] !== target) {
      return c.json(err("CONFLICT", `Cannot transition from ${o.status} to ${target}`), 409);
    }
    await db.run("UPDATE orders SET status = ? WHERE id = ?", target, o.id);
    return c.json(await vendorOrderDetail(db, o.id));
  }

  async function vendorKpis(c: Ctx) {
    const deliveredToday = "status = 'delivered' AND date(created_at) = date('now', 'localtime')";
    const todayDeliveries = ((await db.one(`SELECT COUNT(*) AS n FROM orders WHERE ${deliveredToday}`)) as Row).n as number;
    const todayRevenue = ((await db.one(`SELECT COALESCE(SUM(total), 0) AS s FROM orders WHERE ${deliveredToday}`)) as Row).s as number;
    const activeSubscriptions = ((await db.one("SELECT COUNT(*) AS n FROM subscriptions WHERE status = 'active'")) as Row).n as number;
    const pendingOrders = ((await db.one(
      "SELECT COUNT(*) AS n FROM orders WHERE status IN ('scheduled', 'preparing', 'out_for_delivery')"
    )) as Row).n as number;
    return c.json({ todayDeliveries, todayRevenue, activeSubscriptions, pendingOrders });
  }

  async function vendorSubscriptions(c: Ctx) {
    const rows = await db.all(
      `SELECT s.id, s.product_id, s.quantity, s.frequency, s.start_date, s.delivery_time, s.status, s.next_delivery, s.days,
              p.name AS product_name
       FROM subscriptions s LEFT JOIN products p ON p.id = s.product_id ORDER BY s.id DESC`
    );
    return c.json(rows.map((s) => ({
      id: s.id,
      product: { id: s.product_id, name: s.product_name },
      quantity: s.quantity, frequency: s.frequency, start_date: s.start_date,
      delivery_time: s.delivery_time, status: s.status, next_delivery: s.next_delivery ?? null,
      days: s.days ?? null,
    })));
  }

  // ---------- handlers: subscriptions (user owns only their rows) ----------
  const SUB_FREQUENCIES = new Set([
    "every_day",
    "alternate_days",
    "specific_days",
    "weekly",
    "once_a_week",
  ]);

  function toSub(s: Row) {
    return {
      id: s.id,
      product_id: s.product_id,
      product_name: s.product_name ?? s.product_id,
      quantity: s.quantity,
      frequency: s.frequency,
      start_date: s.start_date,
      delivery_time: s.delivery_time,
      status: s.status,
      next_delivery: s.next_delivery ?? null,
      skip_next: Boolean(s.skip_next ?? 0),
      days: s.days ?? null,
    };
  }

  // Optional `days` wire value: comma-separated short day tokens
  // ("Mon,Wed,Fri"). Returns the normalized string, null when absent/empty.
  function parseDays(raw: unknown): string | null | undefined {
    if (raw === undefined || raw === null) return undefined;
    const s = String(raw).trim();
    if (s === "") return null;
    const valid = new Set(["mon", "tue", "wed", "thu", "fri", "sat", "sun"]);
    const parts = s.split(",").map((p) => p.trim()).filter(Boolean);
    if (parts.length === 0) return null;
    const norm: string[] = [];
    for (const p of parts) {
      const low = p.toLowerCase();
      if (!valid.has(low)) return undefined;
      norm.push(low[0].toUpperCase() + low.slice(1));
    }
    return norm.join(",");
  }

  const SUB_SELECT = `SELECT s.*, p.name AS product_name FROM subscriptions s
    LEFT JOIN products p ON p.id = s.product_id`;

  async function listSubscriptions(c: Ctx) {
    const user = c.get("user");
    const rows = await db.all(`${SUB_SELECT} WHERE s.user_id = ? ORDER BY s.id DESC`, user.id);
    return c.json(rows.map(toSub));
  }

  async function createSubscription(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const productId = String(body?.productId ?? body?.product_id ?? "");
    const quantity = Number(body?.quantity ?? 1);
    const frequency = String(body?.frequency ?? "every_day");
    const startDate = String(body?.startDate ?? body?.start_date ?? "");
    const deliveryTime = String(body?.deliveryTime ?? body?.delivery_time ?? "");
    if (!productId || !(await db.one("SELECT id FROM products WHERE id = ?", productId))) {
      return c.json(err("VALIDATION", "unknown productId"), 400);
    }
    if (!Number.isInteger(quantity) || quantity < 1) {
      return c.json(err("VALIDATION", "quantity must be >= 1"), 400);
    }
    if (!SUB_FREQUENCIES.has(frequency)) {
      return c.json(err("VALIDATION", "unknown frequency"), 400);
    }
    if (!startDate || !deliveryTime) {
      return c.json(err("VALIDATION", "startDate and deliveryTime are required"), 400);
    }
    const days = parseDays(body?.days);
    if (days === undefined && body?.days !== undefined) {
      return c.json(err("VALIDATION", "days must be comma-separated day tokens like Mon,Wed,Fri"), 400);
    }
    const r = await db.run(
      "INSERT INTO subscriptions (user_id, product_id, quantity, frequency, start_date, delivery_time, status, next_delivery, skip_next, days) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, 0, ?)",
      user.id, productId, quantity, frequency, startDate, deliveryTime, startDate, days ?? null
    );
    const s = (await db.one(`${SUB_SELECT} WHERE s.id = ?`, Number(r.lastInsertRowid))) as Row;
    return c.json(toSub(s), 201);
  }

  async function updateSubscription(c: Ctx) {
    const user = c.get("user");
    const id = Number(c.req.param("id"));
    const s = await db.one("SELECT id FROM subscriptions WHERE id = ? AND user_id = ?", id, user.id);
    if (!s) return c.json(err("NOT_FOUND", "Subscription not found"), 404);
    const body = await readJson(c);
    const patch: string[] = [];
    const params: any[] = [];
    if (body?.quantity !== undefined) {
      const q = Number(body.quantity);
      if (!Number.isInteger(q) || q < 1) {
        return c.json(err("VALIDATION", "quantity must be >= 1"), 400);
      }
      patch.push("quantity = ?");
      params.push(q);
    }
    if (body?.frequency !== undefined) {
      const f = String(body.frequency);
      if (!SUB_FREQUENCIES.has(f)) {
        return c.json(err("VALIDATION", "unknown frequency"), 400);
      }
      patch.push("frequency = ?");
      params.push(f);
    }
    if (body?.deliveryTime !== undefined || body?.delivery_time !== undefined) {
      patch.push("delivery_time = ?");
      params.push(String(body.deliveryTime ?? body.delivery_time));
    }
    if (body?.status !== undefined) {
      const st = String(body.status);
      if (st !== "active" && st !== "paused") {
        return c.json(err("VALIDATION", "status must be active or paused"), 400);
      }
      patch.push("status = ?");
      params.push(st);
    }
    if (body?.skipNext !== undefined) {
      patch.push("skip_next = ?");
      params.push(body.skipNext ? 1 : 0);
    }
    if (body?.days !== undefined) {
      const days = parseDays(body.days);
      if (days === undefined) {
        return c.json(err("VALIDATION", "days must be comma-separated day tokens like Mon,Wed,Fri"), 400);
      }
      patch.push("days = ?");
      params.push(days);
    }
    if (patch.length === 0) {
      return c.json(err("VALIDATION", "nothing to update"), 400);
    }
    await db.run(`UPDATE subscriptions SET ${patch.join(", ")} WHERE id = ?`, ...params, id);
    const row = (await db.one(`${SUB_SELECT} WHERE s.id = ?`, id)) as Row;
    return c.json(toSub(row));
  }

  // ---------- handlers: vendor profile / slots / tickets (Slice 1, additive) ----------
  // Minimum code: plain functions over the injected DbClient, authz from
  // c.get("user") (service layer, never client-supplied ids), allowlist
  // validation, parameterized queries only. All routes sit under the
  // existing /api/vendor/* 403 guard above.
  const VENDOR_DEFAULT_SLOTS = ["Morning \u2022 8:00 AM", "Noon \u2022 12:00 PM", "Evening \u2022 6:00 PM"];
  const VENDOR_DEFAULT_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const VENDOR_DAY_SET = new Set(VENDOR_DEFAULT_DAYS);
  const VENDOR_PROFILE_FIELDS = new Set(["name", "phone", "address", "hours"]);

  async function ensureVendorProfile(userId: number) {
    await db.run("INSERT OR IGNORE INTO vendor_profile (user_id) VALUES (?)", userId);
  }

  function toSlotsJson(rows: Row[]) {
    const slots: Record<string, boolean> = {};
    const days: Record<string, boolean> = {};
    for (const r of rows) {
      const k = String(r.slot_key);
      const v = Boolean(r.enabled);
      if (VENDOR_DAY_SET.has(k)) days[k] = v;
      else slots[k] = v;
    }
    return { slots, days };
  }

  async function getVendorProfile(c: Ctx) {
    const user = c.get("user");
    await ensureVendorProfile(user.id);
    const p = (await db.one("SELECT name, phone, address, hours FROM vendor_profile WHERE user_id = ?", user.id)) as Row;
    return c.json({ name: p.name ?? "", phone: p.phone ?? "", address: p.address ?? "", hours: p.hours ?? "" });
  }

  async function patchVendorProfile(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return c.json(err("VALIDATION", "nothing to update"), 400);
    }
    const patch: string[] = [];
    const params: any[] = [];
    for (const key of VENDOR_PROFILE_FIELDS) {
      if (body[key] === undefined) continue;
      if (typeof body[key] !== "string") return c.json(err("VALIDATION", `${key} must be a string`), 400);
      const v = (body[key] as string).trim();
      if (key === "phone" && v !== "" && !/^[0-9]{10}$/.test(v)) {
        return c.json(err("VALIDATION", "phone must be 10 digits"), 400);
      }
      patch.push(`${key} = ?`);
      params.push(v);
    }
    if (patch.length === 0) return c.json(err("VALIDATION", "nothing to update"), 400);
    await ensureVendorProfile(user.id);
    await db.run(`UPDATE vendor_profile SET ${patch.join(", ")} WHERE user_id = ?`, ...params, user.id);
    const p = (await db.one("SELECT name, phone, address, hours FROM vendor_profile WHERE user_id = ?", user.id)) as Row;
    return c.json({ name: p.name ?? "", phone: p.phone ?? "", address: p.address ?? "", hours: p.hours ?? "" });
  }

  async function getVendorSlots(c: Ctx) {
    const user = c.get("user");
    const rows = await db.all("SELECT slot_key, enabled FROM vendor_slots WHERE user_id = ?", user.id);
    if (rows.length === 0) {
      for (const k of [...VENDOR_DEFAULT_SLOTS, ...VENDOR_DEFAULT_DAYS]) {
        await db.run("INSERT OR IGNORE INTO vendor_slots (user_id, slot_key, enabled) VALUES (?, ?, 1)", user.id, k);
      }
      const slots: Record<string, boolean> = {};
      const days: Record<string, boolean> = {};
      for (const k of VENDOR_DEFAULT_SLOTS) slots[k] = true;
      for (const k of VENDOR_DEFAULT_DAYS) days[k] = true;
      return c.json({ slots, days });
    }
    return c.json(toSlotsJson(rows));
  }

  function slotsMapError(v: unknown): string | null {
    if (v === undefined) return null;
    if (!v || typeof v !== "object" || Array.isArray(v)) return "slot values must be booleans";
    for (const val of Object.values(v as Record<string, unknown>)) {
      if (typeof val !== "boolean") return "slot values must be booleans";
    }
    return null;
  }

  async function putVendorSlots(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const sErr = slotsMapError(body?.slots);
    if (sErr) return c.json(err("VALIDATION", sErr), 400);
    const dErr = slotsMapError(body?.days);
    if (dErr) return c.json(err("VALIDATION", dErr), 400);
    if (body?.slots === undefined && body?.days === undefined) {
      return c.json(err("VALIDATION", "nothing to update"), 400);
    }
    const entries: [string, boolean][] = [];
    for (const m of [body?.slots, body?.days]) {
      if (m === undefined) continue;
      for (const [k, v] of Object.entries(m as Record<string, boolean>)) entries.push([k, v]);
    }
    for (const [k, v] of entries) {
      await db.run(
        "INSERT INTO vendor_slots (user_id, slot_key, enabled) VALUES (?, ?, ?) ON CONFLICT(user_id, slot_key) DO UPDATE SET enabled = excluded.enabled",
        user.id, k, v ? 1 : 0
      );
    }
    const rows = await db.all("SELECT slot_key, enabled FROM vendor_slots WHERE user_id = ?", user.id);
    return c.json(toSlotsJson(rows));
  }

  async function listVendorTickets(c: Ctx) {
    const user = c.get("user");
    const rows = await db.all(
      "SELECT t.id, t.subject, t.status, t.created_at, (SELECT COUNT(*) FROM ticket_replies r WHERE r.ticket_id = t.id) AS reply_count FROM support_tickets t WHERE t.vendor_id = ? ORDER BY t.id DESC",
      user.id
    );
    return c.json(rows.map((t) => ({
      id: t.id, subject: t.subject, status: t.status, created_at: t.created_at, reply_count: Number(t.reply_count ?? 0),
    })));
  }

  async function createVendorTicket(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const subject = typeof body?.subject === "string" ? body.subject.trim() : "";
    if (!subject) return c.json(err("VALIDATION", "subject is required"), 400);
    if (subject.length > 200) return c.json(err("VALIDATION", "subject must be at most 200 characters"), 400);
    const now = new Date().toISOString();
    const r = await db.run("INSERT INTO support_tickets (vendor_id, subject, status, created_at) VALUES (?, ?, 'open', ?)", user.id, subject, now);
    const t = (await db.one("SELECT id, subject, status, created_at FROM support_tickets WHERE id = ?", Number(r.lastInsertRowid))) as Row;
    return c.json({ id: t.id, subject: t.subject, status: t.status, created_at: t.created_at }, 201);
  }

  async function getVendorTicket(c: Ctx) {
    const user = c.get("user");
    const t = await db.one("SELECT id, subject, status, created_at FROM support_tickets WHERE id = ? AND vendor_id = ?", Number(c.req.param("id")), user.id);
    if (!t) return c.json(err("NOT_FOUND", "Ticket not found"), 404);
    const replies = await db.all("SELECT id, author, body, created_at FROM ticket_replies WHERE ticket_id = ? ORDER BY id ASC", t.id);
    return c.json({ id: t.id, subject: t.subject, status: t.status, created_at: t.created_at, replies });
  }

  async function replyVendorTicket(c: Ctx) {
    const user = c.get("user");
    const ticketId = Number(c.req.param("id"));
    const t = await db.one("SELECT id FROM support_tickets WHERE id = ? AND vendor_id = ?", ticketId, user.id);
    if (!t) return c.json(err("NOT_FOUND", "Ticket not found"), 404);
    const body = await readJson(c);
    const text = typeof body?.body === "string" ? body.body.trim() : "";
    if (!text) return c.json(err("VALIDATION", "body is required"), 400);
    if (text.length > 2000) return c.json(err("VALIDATION", "body must be at most 2000 characters"), 400);
    const now = new Date().toISOString();
    const r = await db.run("INSERT INTO ticket_replies (ticket_id, author, body, created_at) VALUES (?, 'vendor', ?, ?)", ticketId, text, now);
    const reply = (await db.one("SELECT id, author, body, created_at FROM ticket_replies WHERE id = ?", Number(r.lastInsertRowid))) as Row;
    return c.json(reply, 201);
  }

  // ---------- routes (thin: parse input, call handler) ----------
  app.get("/", (c) => c.json({ ok: true, service: "water-backend" }));
  app.post("/api/auth/register", registerHandler);
  app.post("/api/auth/login", loginHandler);
  app.get("/api/products", listProducts);
  app.get("/api/products/search", searchProducts);
  app.get("/api/addresses", listAddresses);
  app.post("/api/addresses", createAddress);
  app.get("/api/orders", listOrders);
  app.post("/api/orders", createOrder);
  app.patch("/api/orders/:id/cancel", cancelOrder);
  app.get("/api/subscriptions", listSubscriptions);
  app.post("/api/subscriptions", createSubscription);
  app.patch("/api/subscriptions/:id", updateSubscription);
  app.get("/api/vendor/orders", vendorOrders);
  app.patch("/api/vendor/orders/:id", vendorUpdateStatus);
  app.get("/api/vendor/kpis", vendorKpis);
  app.get("/api/vendor/subscriptions", vendorSubscriptions);
  app.get("/api/vendor/profile", getVendorProfile);
  app.patch("/api/vendor/profile", patchVendorProfile);
  app.get("/api/vendor/slots", getVendorSlots);
  app.put("/api/vendor/slots", putVendorSlots);
  app.get("/api/vendor/tickets", listVendorTickets);
  app.post("/api/vendor/tickets", createVendorTicket);
  app.get("/api/vendor/tickets/:id", getVendorTicket);
  app.post("/api/vendor/tickets/:id/replies", replyVendorTicket);

  return app;
}
