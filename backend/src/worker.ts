// Cloudflare Workers adapter: uses the `env.DB` D1 binding, injects it
// into the portable Hono app (./app.ts). No `bun:sqlite` / `Bun.*` here.
// Passwords use WebCrypto PBKDF2-SHA256 (argon2id is Bun-only); each env is
// self-consistent because D1 starts from a fresh seed (see seed.d1.sql).
import { createApp, type DbClient, type Row } from "./app.ts";

// Minimal D1 typings (avoids @cloudflare/workers-types = no new deps).
type D1Prepared = { bind(...p: any[]): { first(): Promise<Row | null>; all(): Promise<{ results: Row[] }>; run(): Promise<{ meta: { last_row_id: number } }> } };
type D1Database = { prepare(sql: string): D1Prepared };
export interface Env {
  DB: D1Database;
}

function d1Client(d1: D1Database): DbClient {
  return {
    all: async (sql: string, ...params: any[]): Promise<Row[]> => {
      const res = await d1.prepare(sql).bind(...params).all();
      return (res.results as Row[]) ?? [];
    },
    one: async (sql: string, ...params: any[]): Promise<Row | null> =>
      (await d1.prepare(sql).bind(...params).first()) ?? null,
    run: async (sql: string, ...params: any[]) => {
      const r = await d1.prepare(sql).bind(...params).run();
      return { lastInsertRowid: r.meta.last_row_id };
    },
  };
}

// ---------- WebCrypto PBKDF2 auth (portable; runs in workerd + Bun) ----------
const PBKDF2_ITER = 100000;

function b64encode(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}
function b64decode(b64: string): Uint8Array {
  const s = atob(b64);
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

export async function hashPassword(pw: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pw), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt: salt as BufferSource, iterations: PBKDF2_ITER, hash: "SHA-256" },
    key,
    256
  );
  return `pbkdf2$${PBKDF2_ITER}$${b64encode(salt)}$${b64encode(new Uint8Array(bits))}`;
}

export async function verifyPassword(pw: string, stored: string): Promise<boolean> {
  try {
    if (!stored.startsWith("pbkdf2$")) return false;
    const parts = stored.split("$");
    if (parts.length !== 4) return false;
    const iter = Number(parts[1]);
    const salt = b64decode(parts[2]);
    const expected = b64decode(parts[3]);
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pw), "PBKDF2", false, ["deriveBits"]);
    const bits = new Uint8Array(
      await crypto.subtle.deriveBits(
        { name: "PBKDF2", salt: salt as BufferSource, iterations: iter, hash: "SHA-256" },
        key,
        expected.length * 8
      )
    );
    if (bits.length !== expected.length) return false;
    let diff = 0;
    for (let i = 0; i < bits.length; i++) diff |= bits[i] ^ expected[i];
    return diff === 0;
  } catch {
    return false;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const app = createApp(d1Client(env.DB), { hashPassword, verifyPassword });
    return app.fetch(request, env);
  },
};
