import type { HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { WebPubSubServiceClient } from "@azure/web-pubsub";

export default async function negotiate(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const hub = request.query.get("hub") ?? "picks";
  context.log("Negotiating pick board SignalR connection", { hub });
  const client = new WebPubSubServiceClient(process.env.AzureSignalRConnectionString ?? "", hub);
  return { status: 200, jsonBody: await client.getClientAccessToken() };
}
