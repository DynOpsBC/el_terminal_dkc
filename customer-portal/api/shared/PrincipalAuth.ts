import type { HttpRequest } from "@azure/functions";

export type Principal = {
  identityProvider: string;
  userId: string;
  userDetails: string;
  userRoles: string[];
  claims: { typ: string; val: string }[];
};

const TENANT_ID_PATTERN = /^[a-z0-9-]{8,80}$/i;

export function readPrincipal(request: HttpRequest): Principal | null {
  const header = request.headers.get("x-ms-client-principal");
  if (!header) return null;
  try {
    const decoded = Buffer.from(header, "base64").toString("utf8");
    return JSON.parse(decoded) as Principal;
  } catch {
    return null;
  }
}

function claim(principal: Principal, type: string): string | undefined {
  return principal.claims?.find((c) => c.typ === type)?.val;
}

/**
 * Throws if the caller is not authenticated *and* not the rightful owner of
 * the requested tenant. Returns the verified tenantId on success.
 */
export function requireTenantOwner(request: HttpRequest, requestedTenantId: string): string {
  const principal = readPrincipal(request);
  if (!principal) throw new AuthError(401, "authentication required");
  const tid = claim(principal, "tid") ?? claim(principal, "http://schemas.microsoft.com/identity/claims/tenantid");
  if (!tid) throw new AuthError(401, "principal missing tid claim");
  if (!TENANT_ID_PATTERN.test(tid)) throw new AuthError(401, "principal tid malformed");
  if (tid.toLowerCase() !== requestedTenantId.toLowerCase()) {
    throw new AuthError(403, "tenant mismatch — you can only manage your own tenant");
  }
  return tid;
}

export class AuthError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}
