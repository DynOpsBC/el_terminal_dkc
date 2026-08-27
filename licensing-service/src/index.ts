// Azure Functions Node.js Programming Model v4 entry point.
// Replaces the per-folder function.json + index.ts pattern. The runtime auto-
// discovers this single file via `main` in package.json and registers each
// route through the `app.http(...)` calls.

import { app } from "@azure/functions";
import licenseIssue from "../license-issue/index.js";
import licenseVerify from "../license-verify/index.js";
import licenseMe from "../license-me/index.js";

app.http("license-issue", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "license/issue",
  handler: licenseIssue,
});

app.http("license-verify", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "license/verify",
  handler: licenseVerify,
});

app.http("license-me", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "license/me",
  handler: licenseMe,
});
