import type { HttpRequest, InvocationContext, HttpResponseInit } from "@azure/functions";
import { signLicense } from "../shared/JwtSigner.js";
import { createLicense as defaultCreateLicense, supersedeActive as defaultSupersedeActive } from "../shared/LicenseStore.js";
import { isAdminAuthorized as defaultIsAdminAuthorized } from "../shared/RequestAuth.js";

type IssueBody = {
  tenantId: string;
  product?: string;
  tier: "Essentials" | "Advanced" | "Enterprise";
  seats: number;
  validUntil: string;       // ISO date
  customerEmail: string;
  replaceActive?: boolean;
};

/**
 * Dependency-injectable deps so unit tests can drop in noop store/auth
 * implementations without spinning up Azurite. Production callers go through
 * the default export which wires the real shared modules.
 */
export type IssueDeps = {
  isAdminAuthorized: (request: HttpRequest) => boolean;
  createLicense: typeof defaultCreateLicense;
  supersedeActive: typeof defaultSupersedeActive;
};

const defaultDeps: IssueDeps = {
  isAdminAuthorized: defaultIsAdminAuthorized,
  createLicense: defaultCreateLicense,
  supersedeActive: defaultSupersedeActive,
};

export async function handleIssue(
  request: HttpRequest,
  context: InvocationContext,
  deps: IssueDeps = defaultDeps,
): Promise<HttpResponseInit> {
  const { isAdminAuthorized, createLicense, supersedeActive } = deps;
  if (!isAdminAuthorized(request)) {
    return { status: 401, jsonBody: { ok: false, error: "admin token required" } };
  }

  const raw = await request.text();
  let body: IssueBody;
  try {
    body = JSON.parse(raw) as IssueBody;
  } catch {
    return { status: 400, jsonBody: { ok: false, error: "invalid JSON body" } };
  }

  if (!body.tenantId || !body.tier || !body.seats || !body.validUntil || !body.customerEmail) {
    return { status: 400, jsonBody: { ok: false, error: "tenantId, tier, seats, validUntil, customerEmail are required" } };
  }
  if (!["Essentials", "Advanced", "Enterprise"].includes(body.tier)) {
    return { status: 400, jsonBody: { ok: false, error: "tier must be Essentials, Advanced or Enterprise" } };
  }
  if (typeof body.seats !== "number" || body.seats < 1) {
    return { status: 400, jsonBody: { ok: false, error: "seats must be a positive integer" } };
  }

  const validUntilSec = Math.floor(new Date(body.validUntil).getTime() / 1000);
  if (!Number.isFinite(validUntilSec) || validUntilSec <= Math.floor(Date.now() / 1000)) {
    return { status: 400, jsonBody: { ok: false, error: "validUntil must be a future ISO date" } };
  }

  const product = body.product ?? "BCWMSApp";

  try {
    if (body.replaceActive) await supersedeActive(body.tenantId);

    const { jwt, claims } = await signLicense({
      sub: cryptoRandomId(),
      tid: body.tenantId,
      product,
      tier: body.tier,
      seats: body.seats,
      email: body.customerEmail,
      validUntil: validUntilSec,
    });

    const record = await createLicense({
      partitionKey: body.tenantId,
      id: claims.sub,
      tier: body.tier,
      seats: body.seats,
      product,
      email: body.customerEmail,
      validUntil: new Date(validUntilSec * 1000).toISOString(),
    });

    return {
      status: 200,
      jsonBody: {
        ok: true,
        id: record.rowKey,
        tier: record.tier,
        seats: record.seats,
        validUntil: record.validUntil,
        kid: claims.kid,
        key: jwt,
      },
    };
  } catch (err) {
    context.error("license/issue failed", err);
    return { status: 500, jsonBody: { ok: false, error: (err as Error).message } };
  }
}

// Azure Functions runtime expects a default export — wraps handleIssue with
// the production deps wired up.
export default async function licenseIssue(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  return handleIssue(request, context);
}

function cryptoRandomId(): string {
  // Use Web Crypto (Functions runtime exposes it) to avoid a node:crypto import collision
  // when the JwtSigner module is mocked in unit tests.
  const buf = new Uint8Array(16);
  crypto.getRandomValues(buf);
  buf[6] = (buf[6] & 0x0f) | 0x40;
  buf[8] = (buf[8] & 0x3f) | 0x80;
  const hex = Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
