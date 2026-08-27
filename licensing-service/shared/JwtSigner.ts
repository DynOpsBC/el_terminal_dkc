import { createPrivateKey, createPublicKey, createSign, createVerify, type KeyObject } from "node:crypto";
import { SecretClient } from "@azure/keyvault-secrets";
import { DefaultAzureCredential } from "@azure/identity";

export type LicenseClaims = {
  iss: string;
  sub: string;          // license id (uuid)
  tid: string;          // BC tenant id (aad guid)
  product: string;      // "BCWMSApp"
  tier: "Essentials" | "Advanced" | "Enterprise";
  seats: number;
  email: string;
  iat: number;          // issued at (seconds)
  exp: number;          // expires at (seconds)
  kid: string;          // key id used to sign
};

let cachedPrivateKey: KeyObject | null = null;
let cachedPublicKey: KeyObject | null = null;
let cachedKid: string | null = null;

async function loadPrivateKey(): Promise<{ key: KeyObject; kid: string }> {
  if (cachedPrivateKey && cachedKid) return { key: cachedPrivateKey, kid: cachedKid };

  // Dev/test path: inline PEM via env (never set in prod).
  const inlinePem = process.env.LICENSE_PRIVATE_KEY_PEM;
  if (inlinePem) {
    cachedPrivateKey = createPrivateKey(inlinePem);
    cachedKid = process.env.LICENSE_SIGNING_KID ?? "dev";
    return { key: cachedPrivateKey, kid: cachedKid };
  }

  // Prod path: KeyVault.
  const vaultUrl = process.env.LICENSE_KEYVAULT_URL;
  const secretName = process.env.LICENSE_PRIVATE_KEY_SECRET ?? "license-signing-key";
  if (!vaultUrl) throw new Error("LICENSE_KEYVAULT_URL or LICENSE_PRIVATE_KEY_PEM must be set");

  const client = new SecretClient(vaultUrl, new DefaultAzureCredential());
  const secret = await client.getSecret(secretName);
  if (!secret.value) throw new Error(`secret ${secretName} empty`);
  cachedPrivateKey = createPrivateKey(secret.value);
  cachedKid = secret.properties.version?.slice(0, 8) ?? "kv";
  return { key: cachedPrivateKey, kid: cachedKid };
}

async function loadPublicKey(): Promise<KeyObject> {
  if (cachedPublicKey) return cachedPublicKey;
  const inlinePem = process.env.LICENSE_PUBLIC_KEY_PEM;
  if (inlinePem) {
    cachedPublicKey = createPublicKey(inlinePem);
    return cachedPublicKey;
  }
  const { key } = await loadPrivateKey();
  cachedPublicKey = createPublicKey(key);
  return cachedPublicKey;
}

function base64url(input: Buffer | string): string {
  const buf = typeof input === "string" ? Buffer.from(input) : input;
  return buf.toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function base64urlDecode(input: string): Buffer {
  const pad = 4 - (input.length % 4 || 4);
  const b64 = input.replace(/-/g, "+").replace(/_/g, "/") + (pad < 4 ? "=".repeat(pad) : "");
  return Buffer.from(b64, "base64");
}

export async function signLicense(claims: Omit<LicenseClaims, "iat" | "exp" | "kid" | "iss"> & {
  iss?: string;
  validFrom?: number;
  validUntil: number;
}): Promise<{ jwt: string; claims: LicenseClaims }> {
  const { key, kid } = await loadPrivateKey();
  const iss = claims.iss ?? "dynops.bcwms.licensing";
  const iat = claims.validFrom ?? Math.floor(Date.now() / 1000);
  const exp = claims.validUntil;
  if (exp <= iat) throw new Error("validUntil must be in the future of validFrom/iat");

  const fullClaims: LicenseClaims = {
    iss,
    sub: claims.sub,
    tid: claims.tid,
    product: claims.product,
    tier: claims.tier,
    seats: claims.seats,
    email: claims.email,
    iat,
    exp,
    kid,
  };

  const header = { alg: "RS256", typ: "JWT", kid };
  const headerPart = base64url(JSON.stringify(header));
  const payloadPart = base64url(JSON.stringify(fullClaims));
  const signingInput = `${headerPart}.${payloadPart}`;

  const signer = createSign("RSA-SHA256");
  signer.update(signingInput);
  signer.end();
  const signature = base64url(signer.sign(key));

  return { jwt: `${signingInput}.${signature}`, claims: fullClaims };
}

export type VerifyResult =
  | { valid: true; claims: LicenseClaims }
  | { valid: false; reason: "format" | "signature" | "expired" | "not_yet_valid" | "tenant_mismatch" | "key" };

export async function verifyLicense(jwt: string, expectedTenantId?: string): Promise<VerifyResult> {
  const parts = jwt.split(".");
  if (parts.length !== 3) return { valid: false, reason: "format" };
  const [headerPart, payloadPart, signaturePart] = parts;
  let header: { alg?: string; kid?: string };
  let payload: LicenseClaims;
  try {
    header = JSON.parse(base64urlDecode(headerPart).toString("utf8")) as { alg?: string; kid?: string };
    payload = JSON.parse(base64urlDecode(payloadPart).toString("utf8")) as LicenseClaims;
  } catch {
    return { valid: false, reason: "format" };
  }
  if (header.alg !== "RS256") return { valid: false, reason: "signature" };

  let publicKey: KeyObject;
  try {
    publicKey = await loadPublicKey();
  } catch {
    return { valid: false, reason: "key" };
  }

  const verifier = createVerify("RSA-SHA256");
  verifier.update(`${headerPart}.${payloadPart}`);
  verifier.end();
  const ok = verifier.verify(publicKey, base64urlDecode(signaturePart));
  if (!ok) return { valid: false, reason: "signature" };

  const now = Math.floor(Date.now() / 1000);
  if (payload.iat && payload.iat > now + 60) return { valid: false, reason: "not_yet_valid" };
  if (payload.exp <= now) return { valid: false, reason: "expired" };
  if (expectedTenantId && payload.tid && payload.tid !== expectedTenantId) {
    return { valid: false, reason: "tenant_mismatch" };
  }

  return { valid: true, claims: payload };
}
