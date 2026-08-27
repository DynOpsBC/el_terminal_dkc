import { createHmac, timingSafeEqual } from "node:crypto";

export type PrinterRegistryConfig = {
  defaultTenant?: string;
  tenants: Record<string, TenantPrinters>;
};

export type TenantPrinters = {
  bcBaseUrl: string;
  bcCompanyId: string;
  /** Legacy short-lived token. Prefer client credentials or managed identity. */
  bcBearer?: string;
  bcTenantId?: string;
  bcClientId?: string;
  bcClientSecret?: string;
  bcScope?: string;
  printerSecrets: Record<string, string>;
};

export class PrinterTokenRegistry {
  static fromEnv(): PrinterTokenRegistry {
    const raw = process.env.PRINT_TENANT_CONFIG_JSON ?? "{}";
    const parsed = JSON.parse(raw) as PrinterRegistryConfig;
    return new PrinterTokenRegistry(parsed);
  }

  constructor(private readonly config: PrinterRegistryConfig) {}

  tenant(tenantId: string): TenantPrinters {
    const key = tenantId || this.config.defaultTenant || "default";
    const tenant = this.config.tenants[key];
    if (!tenant) throw new Error(`Print tenant not configured: ${key}`);
    return tenant;
  }

  secretFor(tenantId: string, printerId: string): string | undefined {
    return this.tenant(tenantId).printerSecrets[printerId];
  }
}

// Process-local replay cache. Entries expire only when the signed timestamp
// itself becomes invalid; a future-dated request can otherwise outlive a
// fixed five-minute cache entry while remaining inside the ±5-minute window.
const seenNonces = new Map<string, number>();

function rememberNonce(key: string, expiresAt: number): boolean {
  const now = Date.now();
  // Lazy GC on every authenticated request.
  for (const [k, expiry] of seenNonces) {
    if (expiry <= now) seenNonces.delete(k);
  }
  if (seenNonces.has(key)) return false;
  seenNonces.set(key, expiresAt);
  return true;
}

export function verifyPrinterSignature(
  headers: Record<string, string | string[] | undefined>,
  method: string,
  requestUrl: string,
  body: string,
  secret: string,
  printerId?: string,
): boolean {
  const sig = header(headers, "x-bcwms-signature");
  const ts = header(headers, "x-bcwms-timestamp");
  const nonce = header(headers, "x-bcwms-nonce");
  const signedPrinterId = header(headers, "x-bcwms-printer-id");
  if (!sig || !ts || !nonce || !secret || !signedPrinterId) return false;
  if (printerId && signedPrinterId !== printerId) return false;
  const tsNum = Number(ts);
  if (!Number.isFinite(tsNum)) return false;
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - tsNum) > 300) return false;

  // Bind the signature to the operation as well as its body. Without method,
  // path and query an intercepted status request could be retargeted to a
  // different job ID before its nonce was consumed.
  const canonical = canonicalRequest(method, requestUrl, body);
  const expected = createHmac("sha256", secret).update(`${ts}.${nonce}.${canonical}`).digest("hex");
  if (!safeEquals(sig, expected)) return false;
  const cacheKey = `${printerId ?? ""}:${nonce}`;
  return rememberNonce(cacheKey, (tsNum + 300) * 1000);
}

export function canonicalRequest(method: string, requestUrl: string, body: string): string {
  const url = new URL(requestUrl);
  // Do not re-serialize URLSearchParams here. Go's url.Values.Encode and the
  // WHATWG URL serializer disagree for otherwise valid characters such as
  // "~" and "*". The agent signs the exact encoded query it sends, so the
  // relay must verify those raw bytes in the same order.
  const rawQuery = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  return `${method.toUpperCase()}\n${url.pathname}\n${rawQuery}\n${body}`;
}

function header(headers: Record<string, string | string[] | undefined>, key: string): string | undefined {
  const value = headers[key] ?? headers[key.toLowerCase()];
  return Array.isArray(value) ? value[0] : value;
}

function safeEquals(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}
