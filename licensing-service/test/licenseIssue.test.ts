import "./setup.js";
import test from "node:test";
import assert from "node:assert/strict";

const { handleIssue } = await import("../license-issue/index.js");
const { verifyLicense } = await import("../shared/JwtSigner.js");
import type { IssueDeps } from "../license-issue/index.js";

type StoredRecord = {
  partitionKey: string;
  rowKey: string;
  tier: string;
  seats: number;
  status: string;
  validUntil: string;
};

function makeDeps() {
  const stored: Record<string, StoredRecord[]> = {};
  const deps: IssueDeps = {
    isAdminAuthorized: (request) =>
      (request.headers.get("x-bcwms-admin-token") ?? "") === "test-admin-token",
    createLicense: async (input) => {
      const partition = String(input.partitionKey ?? "").toLowerCase();
      const record: StoredRecord = {
        partitionKey: partition,
        rowKey: String(input.id ?? "rk-1"),
        tier: input.tier,
        seats: input.seats,
        status: "active",
        validUntil: input.validUntil,
      };
      stored[partition] ??= [];
      stored[partition].push(record);
      return record as never;
    },
    supersedeActive: async (tenantId) => {
      const partition = tenantId.toLowerCase();
      for (const r of stored[partition] ?? []) r.status = "superseded";
    },
  };
  return { stored, deps };
}

function makeRequest(body: unknown, headers: Record<string, string>) {
  const headerMap = new Map(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    text: async () => (typeof body === "string" ? body : JSON.stringify(body)),
    headers: { get: (k: string) => headerMap.get(k.toLowerCase()) ?? null },
    query: { get: () => null },
  } as unknown as Parameters<typeof handleIssue>[0];
}
const fakeContext = { error: () => undefined } as unknown as Parameters<typeof handleIssue>[1];

function futureIso(): string {
  const d = new Date();
  d.setMonth(d.getMonth() + 6);
  return d.toISOString();
}

test("issue — rejects when admin token missing", async () => {
  const { deps } = makeDeps();
  const res = await handleIssue(
    makeRequest({ tenantId: "abc-12345-67", tier: "Advanced", seats: 1, validUntil: futureIso(), customerEmail: "x@x" }, {}),
    fakeContext,
    deps,
  );
  assert.equal(res.status, 401);
});

test("issue — rejects malformed body", async () => {
  const { deps } = makeDeps();
  const res = await handleIssue(makeRequest("not-json", { "x-bcwms-admin-token": "test-admin-token" }), fakeContext, deps);
  assert.equal(res.status, 400);
});

test("issue — rejects unknown tier", async () => {
  const { deps } = makeDeps();
  const res = await handleIssue(
    makeRequest({ tenantId: "abc-12345-67", tier: "Diamond", seats: 1, validUntil: futureIso(), customerEmail: "x@x" }, { "x-bcwms-admin-token": "test-admin-token" }),
    fakeContext,
    deps,
  );
  assert.equal(res.status, 400);
});

test("issue — rejects past validUntil", async () => {
  const { deps } = makeDeps();
  const res = await handleIssue(
    makeRequest({ tenantId: "abc-12345-67", tier: "Advanced", seats: 1, validUntil: "2000-01-01", customerEmail: "x@x" }, { "x-bcwms-admin-token": "test-admin-token" }),
    fakeContext,
    deps,
  );
  assert.equal(res.status, 400);
});

test("issue — successful issue returns signed JWT + record + claims verify", async () => {
  const { deps, stored } = makeDeps();
  const res = await handleIssue(
    makeRequest({ tenantId: "abc-12345-67", tier: "Advanced", seats: 5, validUntil: futureIso(), customerEmail: "ops@acme.com" }, { "x-bcwms-admin-token": "test-admin-token" }),
    fakeContext,
    deps,
  );
  assert.equal(res.status, 200);
  const body = res.jsonBody as Record<string, unknown>;
  assert.equal(body.ok, true);
  assert.equal(body.tier, "Advanced");
  assert.equal(body.seats, 5);
  assert.match(String(body.key), /^eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  const verify = await verifyLicense(String(body.key), "abc-12345-67");
  assert.equal(verify.valid, true);

  const records = stored["abc-12345-67"];
  assert.equal(records.length, 1);
  assert.equal(records[0].tier, "Advanced");
  assert.equal(records[0].seats, 5);
  assert.equal(records[0].status, "active");
});

test("issue — replaceActive supersedes prior records", async () => {
  const { deps, stored } = makeDeps();
  const ok1 = await handleIssue(
    makeRequest({ tenantId: "replace-12345-67", tier: "Essentials", seats: 1, validUntil: futureIso(), customerEmail: "ops@x" }, { "x-bcwms-admin-token": "test-admin-token" }),
    fakeContext,
    deps,
  );
  assert.equal(ok1.status, 200);
  const ok2 = await handleIssue(
    makeRequest({ tenantId: "replace-12345-67", tier: "Enterprise", seats: 50, validUntil: futureIso(), customerEmail: "ops@x", replaceActive: true }, { "x-bcwms-admin-token": "test-admin-token" }),
    fakeContext,
    deps,
  );
  assert.equal(ok2.status, 200);
  const records = stored["replace-12345-67"];
  assert.equal(records.length, 2);
  assert.equal(records[0].status, "superseded");
  assert.equal(records[1].status, "active");
  assert.equal(records[1].tier, "Enterprise");
});
