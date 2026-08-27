import test from "node:test";
import assert from "node:assert/strict";
import { createHmac, randomBytes } from "node:crypto";
import { canonicalRequest, verifyPrinterSignature } from "../PrinterTokenRegistry.js";

const SECRET = "test-secret-1234";
const PRINTER = "WH-LP1";
const METHOD = "POST";
const URL = "https://relay.example/api/print-jobs/42/status?printer=WH-LP1&tenant=default";

function makeHeaders(body: string, nonce = randomBytes(12).toString("hex"), tsOverride?: number, method = METHOD, url = URL, printer = PRINTER) {
  const ts = String(tsOverride ?? Math.floor(Date.now() / 1000));
  const sig = createHmac("sha256", SECRET)
    .update(`${ts}.${nonce}.${canonicalRequest(method, url, body)}`)
    .digest("hex");
  return {
    "x-bcwms-timestamp": ts,
    "x-bcwms-nonce": nonce,
    "x-bcwms-signature": sig,
    "x-bcwms-printer-id": printer,
  };
}

test("signature — fresh nonce passes", () => {
  const body = "{}";
  const headers = makeHeaders(body);
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, body, SECRET, PRINTER), true);
});

test("signature — replay with same nonce is rejected", () => {
  const body = "{}";
  const nonce = randomBytes(12).toString("hex");
  const headers = makeHeaders(body, nonce);
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, body, SECRET, PRINTER), true);
  // Second call with the same nonce must fail (cache hit).
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, body, SECRET, PRINTER), false);
});

test("signature — different printer with same nonce is allowed", () => {
  const body = "{}";
  const nonce = randomBytes(12).toString("hex");
  const urlA = URL.replace("printer=WH-LP1", "printer=PR-A");
  const urlB = URL.replace("printer=WH-LP1", "printer=PR-B");
  const headersA = makeHeaders(body, nonce, undefined, METHOD, urlA, "PR-A");
  const headersB = makeHeaders(body, nonce, undefined, METHOD, urlB, "PR-B");
  assert.equal(verifyPrinterSignature(headersA, METHOD, urlA, body, SECRET, "PR-A"), true);
  // Cache key is per-printer, so a different printer can use the same nonce.
  assert.equal(verifyPrinterSignature(headersB, METHOD, urlB, body, SECRET, "PR-B"), true);
});

test("signature — clock skew >5min is rejected", () => {
  const body = "{}";
  const headers = makeHeaders(body, undefined, Math.floor(Date.now() / 1000) - 400);
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, body, SECRET, PRINTER), false);
});

test("signature — missing nonce is rejected", () => {
  const body = "{}";
  const ts = String(Math.floor(Date.now() / 1000));
  const sig = createHmac("sha256", SECRET).update(`${ts}..${canonicalRequest(METHOD, URL, body)}`).digest("hex");
  const headers = { "x-bcwms-timestamp": ts, "x-bcwms-signature": sig, "x-bcwms-printer-id": PRINTER };
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, body, SECRET, PRINTER), false);
});

test("signature — tampered body invalidates signature", () => {
  const body = "{}";
  const headers = makeHeaders(body);
  assert.equal(verifyPrinterSignature(headers, METHOD, URL, "{\"tampered\":true}", SECRET, PRINTER), false);
});

test("signature — tampered job path is rejected", () => {
  const body = "{}";
  const headers = makeHeaders(body);
  const tamperedUrl = URL.replace("/42/", "/99/");
  assert.equal(verifyPrinterSignature(headers, METHOD, tamperedUrl, body, SECRET, PRINTER), false);
});

test("signature — tampered printer query is rejected", () => {
  const body = "{}";
  const headers = makeHeaders(body);
  const tamperedUrl = URL.replace("printer=WH-LP1", "printer=WH-LP2");
  assert.equal(verifyPrinterSignature(headers, METHOD, tamperedUrl, body, SECRET, PRINTER), false);
});

test("canonical request preserves Go-encoded query bytes", () => {
  const goEncodedUrl = "https://relay.example/api/print-jobs?agent=agent-a%2Ab&printer=WH~LP&tenant=tenant+west&top=10";
  assert.equal(
    canonicalRequest("GET", goEncodedUrl, ""),
    "GET\n/api/print-jobs\nagent=agent-a%2Ab&printer=WH~LP&tenant=tenant+west&top=10\n",
  );
});

test("Go/relay canonical HMAC golden vector", () => {
  const timestamp = "1700000000";
  const nonce = "00112233445566778899aabbccddeeff";
  const goEncodedUrl = "https://relay.example/api/print-jobs?agent=agent-a%2Ab&printer=WH~LP&tenant=tenant+west&top=10";
  const signature = createHmac("sha256", SECRET)
    .update(`${timestamp}.${nonce}.${canonicalRequest("GET", goEncodedUrl, "")}`)
    .digest("hex");
  assert.equal(signature, "68a74d5c55d2040c3623ee0755c55f91862c2f3cd4caa2916916e3b170aaafa1");
});
