// `apiBase` covers Static Web App attached Functions (releases, bc/trigger-update).
// `licensingBase` points at the licensing-service Azure Function for /license/*
// because those endpoints don't live in customer-portal/api/.
const apiBase = (import.meta.env.VITE_PORTAL_API_BASE as string | undefined) ?? "/api";
const licensingBase = (import.meta.env.VITE_PORTAL_LICENSING_URL as string | undefined) ?? apiBase;

export type LicenseSummary = {
  ok: true;
  tenantId: string;
  active: null | {
    id: string;
    tier: "Essentials" | "Advanced" | "Enterprise";
    seats: number;
    product: string;
    email: string;
    issuedAt: string;
    validUntil: string;
    status: string;
  };
};

export type ReleaseEntry = {
  version: string;
  channel: "stable" | "preview";
  publishedAt: string;
  notes: string;
  bcAppUrl?: string;
  apkUrl?: string;
  agentBinaries?: { os: string; arch: string; url: string }[];
};

async function fetchJson<T>(path: string, init?: RequestInit, base: string = apiBase): Promise<T> {
  const url = `${base.replace(/\/$/, "")}${path}`;
  const response = await fetch(url, {
    credentials: "include",
    ...init,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    const message = await response.text();
    throw new Error(`HTTP ${response.status} — ${message.slice(0, 200)}`);
  }
  return (await response.json()) as T;
}

export async function getMyLicense(tenantId: string, jwt?: string): Promise<LicenseSummary> {
  return fetchJson<LicenseSummary>(
    `/api/license/me?tenant=${encodeURIComponent(tenantId)}`,
    { method: "GET", headers: jwt ? { "X-Bcwms-License-Key": jwt } : undefined },
    licensingBase,
  );
}

export async function issueLicense(payload: {
  tenantId: string;
  tier: "Essentials" | "Advanced" | "Enterprise";
  seats: number;
  validUntil: string;
  customerEmail: string;
  adminToken: string;
  replaceActive?: boolean;
}): Promise<{ ok: true; id: string; key: string; tier: string; seats: number; validUntil: string }> {
  return fetchJson(
    `/api/license/issue`,
    {
      method: "POST",
      headers: { "X-Bcwms-Admin-Token": payload.adminToken },
      body: JSON.stringify({
        tenantId: payload.tenantId,
        tier: payload.tier,
        seats: payload.seats,
        validUntil: payload.validUntil,
        customerEmail: payload.customerEmail,
        replaceActive: payload.replaceActive ?? false,
      }),
    },
    licensingBase,
  );
}

export async function getReleases(): Promise<ReleaseEntry[]> {
  return fetchJson<ReleaseEntry[]>("/releases");
}

export async function triggerBcUpdate(payload: { tenantId: string; environment: string; version: string }): Promise<{ ok: boolean }> {
  return fetchJson(`/bc/trigger-update`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
