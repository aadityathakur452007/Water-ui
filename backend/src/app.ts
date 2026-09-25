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

// Full order view for the owning user.
async function userOrderDetail(db: DbClient, orderId: number): Promise<any> {
  const o = (await db.one("SELECT * FROM orders WHERE id = ?", orderId)) as Row;
  const items = (await db.all("SELECT product_id, name, qty, price FROM order_items WHERE order_id = ?", orderId))
    .map((i) => ({ productId: i.product_id, name: i.name, qty: i.qty, price: i.price }));
  const a = o.address_id ? await db.one("SELECT id, label, line, city FROM addresses WHERE id = ?", o.address_id) : null;
  return {
    id: o.id, type: o.type, status: o.status, total: o.total, slot: o.slot ?? null,
    address: a ? { id: a.id, label: a.label, line: a.line, city: a.city } : null,
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
  const a = o.address_id ? await db.one("SELECT label, line, city FROM addresses WHERE id = ?", o.address_id) : null;
  const hasCustomer = o.customer_name != null || o.customer_phone != null || o.customer_email != null;
  return {
    id: o.id, type: o.type, status: o.status, total: o.total, slot: o.slot ?? null,
    address: a ? { label: a.label, line: a.line, city: a.city } : null,
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
      await db.all("SELECT id, label, line, city FROM addresses WHERE user_id = ? ORDER BY id ASC", user.id)
    );
  }

  async function createAddress(c: Ctx) {
    const user = c.get("user");
    const body = await readJson(c);
    const label = String(body?.label ?? "").trim();
    const line = String(body?.line ?? "").trim();
    const city = String(body?.city ?? "").trim();
    if (!label || !line || !city) return c.json(err("VALIDATION", "label, line and city are required"), 400);
    const r = await db.run("INSERT INTO addresses (user_id, label, line, city) VALUES (?, ?, ?, ?)", user.id, label, line, city);
    const a = (await db.one("SELECT id, label, line, city FROM addresses WHERE id = ?", Number(r.lastInsertRowid))) as Row;
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
      const r = await db.run("INSERT INTO addresses (user_id, label, line, city) VALUES (?, ?, ?, ?)", user.id, label, line, city);
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
      `SELECT s.id, s.product_id, s.quantity, s.frequency, s.start_date, s.delivery_time, s.status, s.next_delivery,
              p.name AS product_name
       FROM subscriptions s LEFT JOIN products p ON p.id = s.product_id ORDER BY s.id DESC`
    );
    return c.json(rows.map((s) => ({
      id: s.id,
      product: { id: s.product_id, name: s.product_name },
      quantity: s.quantity, frequency: s.frequency, start_date: s.start_date,
      delivery_time: s.delivery_time, status: s.status, next_delivery: s.next_delivery ?? null,
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
    };
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
    const r = await db.run(
      "INSERT INTO subscriptions (user_id, product_id, quantity, frequency, start_date, delivery_time, status, next_delivery, skip_next) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, 0)",
      user.id, productId, quantity, frequency, startDate, deliveryTime, startDate
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
    if (patch.length === 0) {
      return c.json(err("VALIDATION", "nothing to update"), 400);
    }
    await db.run(`UPDATE subscriptions SET ${patch.join(", ")} WHERE id = ?`, ...params, id);
    const row = (await db.one(`${SUB_SELECT} WHERE s.id = ?`, id)) as Row;
    return c.json(toSub(row));
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

  return app;
}
