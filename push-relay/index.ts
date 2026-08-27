import { app } from "@azure/functions";
import printJobsClaim from "./print-jobs-claim/index.js";
import printJobsGet from "./print-jobs-get/index.js";
import printJobsStatus from "./print-jobs-status/index.js";
import negotiate from "./signalr/negotiate/index.js";
import webhook from "./webhook/index.js";

// Azure Functions Node programming model v4: importing this entry point
// registers every HTTP route. Keep all functions in the same model so the
// runtime does not silently ignore legacy function.json definitions.
app.http("print-jobs-get", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "print-jobs",
  handler: printJobsGet,
});

app.http("print-jobs-claim", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "print-jobs/{jobId:int}/claim",
  handler: printJobsClaim,
});

app.http("print-jobs-status", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "print-jobs/{jobId:int}/status",
  handler: printJobsStatus,
});

app.http("bc-webhook", {
  methods: ["POST"],
  authLevel: "function",
  route: "bc/webhook",
  handler: webhook,
});

app.http("signalr-negotiate", {
  methods: ["POST"],
  authLevel: "function",
  route: "signalr/negotiate",
  handler: negotiate,
});
