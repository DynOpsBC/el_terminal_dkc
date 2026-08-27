import type { TenantPrinters } from "./PrinterTokenRegistry.js";
import { ClientSecretCredential, DefaultAzureCredential, type TokenCredential } from "@azure/identity";

const credentialCache = new Map<string, TokenCredential>();
const lastHeartbeatAt = new Map<string, number>();
const HEARTBEAT_INTERVAL_MS = 60_000;
const CLAIM_LEASE_MS = 15 * 60_000;

export type PrintJobDto = {
  jobId: number;
  sourceDoc: string;
  reportId?: number;
  printerId: string;
  channel: string;
  format: string;
  status: string;
  copies: number;
  payload: string;
  payloadSize: number;
  createdAt: string;
  agentId?: string;
  correlationId?: string;
};

export class BcODataClient {
  private readonly credential?: TokenCredential;

  constructor(private readonly tenant: TenantPrinters) {
    const clientCredentialParts = [tenant.bcTenantId, tenant.bcClientId, tenant.bcClientSecret];
    const configuredParts = clientCredentialParts.filter(Boolean).length;
    if (configuredParts > 0 && configuredParts < clientCredentialParts.length) {
      throw new Error("bcTenantId, bcClientId and bcClientSecret must be configured together");
    }
    if (configuredParts === clientCredentialParts.length) {
      const cacheKey = `client:${tenant.bcTenantId}:${tenant.bcClientId}`;
      let credential = credentialCache.get(cacheKey);
      if (!credential) {
        credential = new ClientSecretCredential(
          tenant.bcTenantId!,
          tenant.bcClientId!,
          tenant.bcClientSecret!,
        );
        credentialCache.set(cacheKey, credential);
      }
      this.credential = credential;
    } else if (!tenant.bcBearer) {
      const cacheKey = "managed-identity";
      let credential = credentialCache.get(cacheKey);
      if (!credential) {
        credential = new DefaultAzureCredential();
        credentialCache.set(cacheKey, credential);
      }
      this.credential = credential;
    }
  }

  private base(): string {
    return `${this.tenant.bcBaseUrl.replace(/\/$/, "")}/api/dynops/warehouse/v2.0/companies(${this.tenant.bcCompanyId})/printJobs`;
  }

  private printersBase(): string {
    return `${this.tenant.bcBaseUrl.replace(/\/$/, "")}/api/dynops/warehouse/v2.0/companies(${this.tenant.bcCompanyId})/printerAgents`;
  }

  private async headers(): Promise<Record<string, string>> {
    let accessToken = "";
    if (this.credential) {
      const token = await this.credential?.getToken(
        this.tenant.bcScope ?? "https://api.businesscentral.dynamics.com/.default",
      );
      accessToken = token?.token ?? "";
    } else
      accessToken = this.tenant.bcBearer ?? "";
    if (!accessToken) throw new Error("No Business Central access token could be acquired");
    return {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json",
      "Content-Type": "application/json",
    };
  }

  async listQueued(printerId: string, top = 10): Promise<PrintJobDto[]> {
    const leaseCutoff = new Date(Date.now() - CLAIM_LEASE_MS).toISOString();
    const filter = encodeURIComponent(
      `channel eq 'SelfHosted' and status eq 'Queued' and printerId eq '${printerId.replace(/'/g, "''")}' and (agentId eq '' or claimedAt lt ${leaseCutoff})`,
    );
    const url = `${this.base()}?$filter=${filter}&$top=${top}&$orderby=createdAt`;
    const response = await fetch(url, { headers: await this.headers() });
    if (!response.ok) {
      throw new Error(`BC OData GET failed: ${response.status} ${await response.text()}`);
    }
    const json = (await response.json()) as { value: PrintJobDto[] };
    return json.value ?? [];
  }

  async heartbeat(printerId: string, agentId: string): Promise<boolean> {
    const heartbeatKey = `${this.tenant.bcBaseUrl}:${this.tenant.bcCompanyId}:${printerId}`;
    const now = Date.now();
    if (now - (lastHeartbeatAt.get(heartbeatKey) ?? 0) < HEARTBEAT_INTERVAL_MS) return true;
    const escapedPrinterId = printerId.replace(/'/g, "''");
    const url = `${this.printersBase()}('${escapedPrinterId}')/Microsoft.NAV.heartbeat`;
    const response = await fetch(url, {
      method: "POST",
      headers: await this.headers(),
      body: JSON.stringify({ agentId }),
    });
    const ok = await this.actionResult(response);
    if (ok) lastHeartbeatAt.set(heartbeatKey, now);
    return ok;
  }

  async claim(jobId: number, agentId: string, printerId: string): Promise<boolean> {
    const url = `${this.base()}(${jobId})/Microsoft.NAV.claimForPrinter`;
    const response = await fetch(url, {
      method: "POST",
      headers: await this.headers(),
      body: JSON.stringify({ agentId, printerId }),
    });
    return this.actionResult(response);
  }

  async markStatus(jobId: number, success: boolean, message: string, agentId: string, printerId: string): Promise<boolean> {
    const action = success ? "markSuccessForPrinter" : "markFailureForPrinter";
    const url = `${this.base()}(${jobId})/Microsoft.NAV.${action}`;
    const response = await fetch(url, {
      method: "POST",
      headers: await this.headers(),
      body: JSON.stringify({ message, agentId, printerId }),
    });
    return this.actionResult(response);
  }

  private async actionResult(response: Response): Promise<boolean> {
    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(`BC OData action failed: ${response.status} ${responseText}`);
    }
    let body: { value?: boolean };
    try {
      body = JSON.parse(responseText) as { value?: boolean };
    } catch {
      throw new Error("BC OData action returned an invalid JSON response");
    }
    if (typeof body.value !== "boolean") {
      throw new Error("BC OData action response did not contain a Boolean value");
    }
    return body.value === true;
  }
}
