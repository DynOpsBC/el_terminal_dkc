import test from "node:test";
import assert from "node:assert/strict";

const { AuthError, requireTenantOwner, readPrincipal } = await import("../shared/PrincipalAuth.js");

function makeRequest(principalHeader: string | null): Parameters<typeof requireTenantOwner>[0] {
  return {
    headers: {
      get: (k: string) => (k.toLowerCase() === "x-ms-client-principal" ? principalHeader : null),
    },
  } as unknown as Parameters<typeof requireTenantOwner>[0];
}

function encodePrincipal(claims: { tid?: string; oid?: string }): string {
  const payload = {
    identityProvider: "aad",
    userId: claims.oid ?? "user-id",
    userDetails: "user@example.com",
    userRoles: ["authenticated"],
    claims: [
      ...(claims.tid ? [{ typ: "tid", val: claims.tid }] : []),
      ...(claims.oid ? [{ typ: "oid", val: claims.oid }] : []),
    ],
  };
  return Buffer.from(JSON.stringify(payload)).toString("base64");
}

test("requireTenantOwner — throws 401 when header missing", () => {
  assert.throws(() => requireTenantOwner(makeRequest(null), "7fa2357e-26f2-4174-8e16-a713981356b8"), (err: unknown) => err instanceof AuthError && err.status === 401);
});

test("requireTenantOwner — throws 401 when tid claim missing", () => {
  const header = encodePrincipal({});
  assert.throws(() => requireTenantOwner(makeRequest(header), "7fa2357e-26f2-4174-8e16-a713981356b8"), (err: unknown) => err instanceof AuthError && err.status === 401);
});

test("requireTenantOwner — throws 401 when tid malformed (contains shell metachars)", () => {
  const header = encodePrincipal({ tid: "; rm -rf /" });
  assert.throws(() => requireTenantOwner(makeRequest(header), "7fa2357e-26f2-4174-8e16-a713981356b8"), (err: unknown) => err instanceof AuthError && err.status === 401);
});

test("requireTenantOwner — throws 403 on tenant mismatch", () => {
  const header = encodePrincipal({ tid: "11111111-2222-3333-4444-555555555555" });
  assert.throws(() => requireTenantOwner(makeRequest(header), "7fa2357e-26f2-4174-8e16-a713981356b8"), (err: unknown) => err instanceof AuthError && err.status === 403);
});

test("requireTenantOwner — succeeds for matching tid (case-insensitive)", () => {
  const header = encodePrincipal({ tid: "7FA2357E-26F2-4174-8E16-A713981356B8" });
  const tid = requireTenantOwner(makeRequest(header), "7fa2357e-26f2-4174-8e16-a713981356b8");
  assert.equal(tid, "7FA2357E-26F2-4174-8E16-A713981356B8");
});

test("readPrincipal — returns null when header missing", () => {
  assert.equal(readPrincipal(makeRequest(null)), null);
});

test("readPrincipal — returns null when header is not valid base64 JSON", () => {
  assert.equal(readPrincipal(makeRequest("not-base64-json")), null);
});
