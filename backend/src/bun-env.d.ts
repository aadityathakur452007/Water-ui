// Minimal ambient declarations so `tsc --noEmit` passes with zero @types
// packages. Runtime is Bun (bun:sqlite, Bun.password, Bun.serve) plus
// node:crypto for token generation. No bcrypt, no ORM.
declare const Bun: any;
declare const process: any;

interface ImportMeta {
  readonly main: boolean;
}

declare module "bun:sqlite" {
  export class Database {
    constructor(path?: string);
    exec(sql: string): void;
    query(sql: string): any;
    transaction<T extends (...args: any[]) => any>(fn: T): T;
    close(): void;
  }
}

declare module "node:crypto" {
  export function randomBytes(n: number): any;
}

declare module "node:fs" {
  export function readFileSync(p: string, enc: string): string;
  export function mkdirSync(p: string, opts?: any): void;
}

declare module "node:path" {
  export function dirname(p: string): string;
  export function join(...parts: string[]): string;
}

declare module "node:url" {
  export function fileURLToPath(url: string | URL): string;
}
