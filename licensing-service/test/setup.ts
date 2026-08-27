// Shared one-time setup for the test suite. Every spec file imports this
// before touching `JwtSigner` so all tests sign with the same key — module
// state in JwtSigner is cached after the first call.

import { generateKeyPairSync } from "node:crypto";

if (!process.env.LICENSE_PRIVATE_KEY_PEM) {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  process.env.LICENSE_PRIVATE_KEY_PEM = privateKey.export({ type: "pkcs8", format: "pem" }) as string;
  process.env.LICENSE_PUBLIC_KEY_PEM = publicKey.export({ type: "spki", format: "pem" }) as string;
  process.env.LICENSE_SIGNING_KID = "test";
  process.env.LICENSE_ADMIN_TOKEN = "test-admin-token";
}
