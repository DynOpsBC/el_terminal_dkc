import type { HttpRequest, InvocationContext, HttpResponseInit } from "@azure/functions";
import { listActiveByTenant } from "../shared/LicenseStore.js";
import { verifyLicense } from "../shared/JwtSigner.js";
import { isAdminAuthorized } from "../shared/RequestAuth.js";

const EMAIL_RE = /^([^@]{1,2}).*?(@.*)$/;

function maskEmail(email: string): string {
  return email.replace(EMAIL_RE, (_, head, tail) => `${head}***${tail}`);
}

export default async function licenseMe(
  request: HttpRequest,
  _context: InvocationContext,
): Promise<HttpResponseInit> {
  const tenantId = request.query.get("tenant");
  if (!tenantId) {
    return { status: 400, jsonBody: { ok: false, error: "missing 'tenant' query" } };
  }

  const admin = isAdminAuthorized(request);
  let callerKey = request.headers.get("x-bcwms-license-key") ?? "";
  if (!callerKey) {
    const bearer = request.headers.get("authorization") ?? "";
    if (bearer.toLowerCase().startsWith("bearer ")) callerKey = bearer.slice(7).trim();
  }

  if (!admin) {
    if (!callerKey) {
      return { status: 401, jsonBody: { ok: false, error: "supply X-Bcwms-License-Key with the tenant's JWT, or X-Bcwms-Admin-Token" } };
    }
    const verify = await verifyLicense(callerKey, tenantId);
    if (!verify.valid) {
      return { status: 401, jsonBody: { ok: false, error: `license key not valid: ${verify.reason}` } };
    }
  }

  let records;
  try {
    records = await listActiveByTenant(tenantId);
  } catch (err) {
    return { status: 400, jsonBody: { ok: false, error: (err as Error).message } };
  }

  if (records.length === 0) {
    return {
      status: 200,
      headers: { "Cache-Control": "private, max-age=300" },
      jsonBody: { ok: true, tenantId, active: null },
    };
  }

  records.sort((a, b) => (a.validUntil > b.validUntil ? -1 : 1));
  const current = records[0];

  return {
    status: 200,
    headers: { "Cache-Control": "private, max-age=300" },
    jsonBody: {
      ok: true,
      tenantId,
      active: {
        id: current.rowKey,
        tier: current.tier,
        seats: current.seats,
        product: current.product,
        email: admin ? current.email : maskEmail(current.email),
        issuedAt: current.issuedAt,
        validUntil: current.validUntil,
        status: current.status,
      },
    },
  };
}
