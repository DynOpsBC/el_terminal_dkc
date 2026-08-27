import { createHmac, timingSafeEqual } from "node:crypto";

export function verifyHmac(headers: Record<string, string | string[] | undefined>, body: string | Buffer, secret: string): boolean {
  const token = header(headers, "aeg-sas-token");
  if (!token || !secret) return false;
  const params = new URLSearchParams(token.replace(/^SharedAccessSignature\s+/i, ""));
  const expiry = Number(params.get("se") ?? "0");
  const signature = params.get("sig") ?? "";
  if (!signature || !expiry) return false;
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(expiry - now) > 300) return false;
  const expected = createHmac("sha256", secret).update(typeof body === "string" ? body : body.toString("utf8")).digest("base64");
  return safeEquals(signature, expected);
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
