import type { HttpRequest } from "@azure/functions";

/**
 * Internal admin endpoints (`/license/issue`, revoke) require an admin token.
 * Tenant-scoped endpoints (`/license/verify`, `/license/me`) are open but
 * still rate-limited by the Function host.
 */
export function isAdminAuthorized(request: HttpRequest): boolean {
  const expected = process.env.LICENSE_ADMIN_TOKEN;
  if (!expected) return false;
  const supplied = request.headers.get("x-bcwms-admin-token") ?? "";
  if (!supplied || supplied.length !== expected.length) return false;
  let result = 0;
  for (let i = 0; i < supplied.length; i++) result |= supplied.charCodeAt(i) ^ expected.charCodeAt(i);
  return result === 0;
}
