import type { HttpRequest, InvocationContext, HttpResponseInit } from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { AuthError, requireTenantOwner } from "../shared/PrincipalAuth.js";

const TENANT_ID_PATTERN = /^[a-z0-9-]{8,80}$/i;
const APP_ID = "984e25aa-07c2-4401-babc-88f975303a52"; // BCWMSApp id from al/app.json

type Body = { tenantId: string; environment: string; version: string };

function assertSafe(value: string, pattern: RegExp, name: string): string {
  if (!pattern.test(value)) throw new Error(`invalid ${name}`);
  return value;
}

export default async function triggerUpdate(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const raw = await request.text();
  let body: Body;
  try {
    body = JSON.parse(raw) as Body;
  } catch {
    return { status: 400, jsonBody: { ok: false, error: "invalid JSON body" } };
  }
  if (!body.tenantId || !body.environment || !body.version) {
    return { status: 400, jsonBody: { ok: false, error: "tenantId, environment, version are required" } };
  }

  let tenantId: string;
  let envName: string;
  let version: string;
  try {
    tenantId = assertSafe(body.tenantId, TENANT_ID_PATTERN, "tenantId");
    envName = assertSafe(body.environment, /^[A-Za-z0-9_-]{1,30}$/, "environment");
    version = assertSafe(body.version, /^\d+\.\d+\.\d+\.\d+$/, "version");
  } catch (err) {
    return { status: 400, jsonBody: { ok: false, error: (err as Error).message } };
  }

  // The caller must be the verified owner of the AAD tenant they're upgrading.
  // Static Web App EasyAuth injects `x-ms-client-principal` with the signed-in
  // claims; the tid claim must match the requested tenantId.
  try {
    requireTenantOwner(request, tenantId);
  } catch (err) {
    if (err instanceof AuthError) {
      return { status: err.status, jsonBody: { ok: false, error: err.message } };
    }
    throw err;
  }

  const credential = new DefaultAzureCredential();
  const tokenResponse = await credential.getToken("https://api.businesscentral.dynamics.com/.default");
  if (!tokenResponse) {
    return { status: 502, jsonBody: { ok: false, error: "could not acquire BC admin token" } };
  }

  // BC Admin Center upgrade API is tenant-scoped — the customer's AAD tenant
  // GUID is the first path segment. The previous tenantless URL silently
  // 404'd against api.businesscentral.dynamics.com because the host requires
  // a tenant context. See:
  // https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/administration-center-api_environments
  const url = `https://api.businesscentral.dynamics.com/admin/v2.21/${tenantId}/applications/BusinessCentral/environments/${envName}/apps/${APP_ID}/upgrade`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tokenResponse.token}`,
      "Content-Type": "application/json",
      "X-Bcwms-Source": "customer-portal",
    },
    body: JSON.stringify({ targetVersion: version }),
  });

  if (!response.ok) {
    const detail = await response.text();
    context.warn(`BC upgrade failed ${response.status} — tenant=${tenantId} env=${envName} version=${version} ${detail.slice(0, 200)}`);
    return { status: 502, jsonBody: { ok: false, error: `BC admin api returned ${response.status}` } };
  }

  return { status: 202, jsonBody: { ok: true, tenantId, environment: envName, version } };
}
