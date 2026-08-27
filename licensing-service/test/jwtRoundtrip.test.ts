import "./setup.js";
import test from "node:test";
import assert from "node:assert/strict";

const { signLicense, verifyLicense } = await import("../shared/JwtSigner.js");

test("sign + verify round trip — valid", async () => {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const { jwt, claims } = await signLicense({
    sub: "abc",
    tid: "tenant-1",
    product: "BCWMSApp",
    tier: "Advanced",
    seats: 12,
    email: "ops@example.com",
    validUntil: exp,
  });
  const result = await verifyLicense(jwt, "tenant-1");
  assert.equal(result.valid, true);
  if (result.valid) {
    assert.equal(result.claims.tier, "Advanced");
    assert.equal(result.claims.seats, 12);
    assert.equal(result.claims.tid, "tenant-1");
    assert.equal(result.claims.sub, "abc");
    assert.equal(result.claims.exp, exp);
    assert.equal(claims.kid, "test");
  }
});

test("verify — tenant mismatch", async () => {
  const { jwt } = await signLicense({
    sub: "a",
    tid: "tenant-A",
    product: "BCWMSApp",
    tier: "Essentials",
    seats: 1,
    email: "x@x",
    validUntil: Math.floor(Date.now() / 1000) + 100,
  });
  const result = await verifyLicense(jwt, "tenant-B");
  assert.equal(result.valid, false);
  if (!result.valid) assert.equal(result.reason, "tenant_mismatch");
});

test("verify — expired", async () => {
  const exp = Math.floor(Date.now() / 1000) - 10;
  const { jwt } = await signLicense({
    sub: "a",
    tid: "t",
    product: "p",
    tier: "Essentials",
    seats: 1,
    email: "e",
    validFrom: exp - 100,
    validUntil: exp,
  });
  const result = await verifyLicense(jwt, "t");
  assert.equal(result.valid, false);
  if (!result.valid) assert.equal(result.reason, "expired");
});

test("sign — rejects validUntil <= iat", async () => {
  const now = Math.floor(Date.now() / 1000);
  await assert.rejects(
    () =>
      signLicense({
        sub: "a",
        tid: "t",
        product: "p",
        tier: "Essentials",
        seats: 1,
        email: "e",
        validFrom: now,
        validUntil: now,
      }),
    /validUntil/,
  );
});

test("verify — bad signature", async () => {
  const { jwt } = await signLicense({
    sub: "a",
    tid: "t",
    product: "p",
    tier: "Essentials",
    seats: 1,
    email: "e",
    validUntil: Math.floor(Date.now() / 1000) + 100,
  });
  // Flip a character in the middle of the signature segment. Replacing
  // only the last char is flaky because some base64url chars decode to
  // the same trailing byte after rounding bits.
  const dot = jwt.lastIndexOf(".");
  const mid = dot + Math.floor((jwt.length - dot) / 2);
  const flipped = jwt[mid] === "A" ? "B" : "A";
  const tampered = jwt.slice(0, mid) + flipped + jwt.slice(mid + 1);
  const result = await verifyLicense(tampered, "t");
  assert.equal(result.valid, false);
});

test("verify — malformed", async () => {
  const result = await verifyLicense("not.a.jwt-payload", "t");
  assert.equal(result.valid, false);
  if (!result.valid) assert.equal(result.reason, "format");
});
