// BCWMS web API client — port of Android BcApi.kt.
// Token, environment and company are persisted to localStorage.
// All custom-API calls go through the dynops/warehouse/v2.0 base; getWithStandardFallback
// retries on 404 against the standard /api/v2.0 base.

export const TENANT = "7fa2357e-26f2-4174-8e16-a713981356b8";
export const DEFAULT_ENVIRONMENT = "SandboxUS";
export const DEFAULT_COMPANY_ID = "1534369d-f248-f111-b478-7c1e521cfdf0";
export const DEFAULT_COMPANY_NAME = "CRONUS USA, Inc.";
export const BC_RESOURCE = "https://api.businesscentral.dynamics.com";
export const KNOWN_ENVIRONMENTS = ["SandboxUS", "CustomerSandbox"];

const KEY_TOKEN = "bcwms.token";
const KEY_ENV = "bcwms.env";
const KEY_COMPANY_ID = "bcwms.companyId";
const KEY_COMPANY_NAME = "bcwms.companyName";

export interface ApiResult {
  ok: boolean;
  httpCode: number;
  body: string;
}

export interface Company {
  id: string;
  name: string;
  displayName: string;
}

// ---- Persistence ----
export const getToken = (): string => localStorage.getItem(KEY_TOKEN) ?? "";
export const hasToken = (): boolean => getToken().trim().length > 0;
export const saveToken = (token: string): void => {
  localStorage.setItem(KEY_TOKEN, token.trim());
};
export const clearToken = (): void => localStorage.removeItem(KEY_TOKEN);

export const getEnvironment = (): string =>
  localStorage.getItem(KEY_ENV) ?? DEFAULT_ENVIRONMENT;
export const setEnvironment = (env: string): void => {
  localStorage.setItem(KEY_ENV, env);
};

export const getCompanyId = (): string =>
  localStorage.getItem(KEY_COMPANY_ID) ?? DEFAULT_COMPANY_ID;
export const getCompanyName = (): string =>
  localStorage.getItem(KEY_COMPANY_NAME) ?? DEFAULT_COMPANY_NAME;
export const setCompany = (id: string, name: string): void => {
  localStorage.setItem(KEY_COMPANY_ID, id);
  localStorage.setItem(KEY_COMPANY_NAME, name);
};

// ---- URL builders ----
const customApiBase = () =>
  `${BC_RESOURCE}/v2.0/${TENANT}/${getEnvironment()}/api/dynops/warehouse/v2.0/companies(${getCompanyId()})`;
const standardApiBase = () =>
  `${BC_RESOURCE}/v2.0/${TENANT}/${getEnvironment()}/api/v2.0/companies(${getCompanyId()})`;
export const companiesUrl = (env: string) =>
  `${BC_RESOURCE}/v2.0/${TENANT}/${env}/api/v2.0/companies?$select=id,name,displayName`;

// ---- Core request ----
async function request(
  method: string,
  path: string,
  body: string | null,
): Promise<ApiResult> {
  const token = getToken();
  if (!token) {
    return {
      ok: false,
      httpCode: 0,
      body: "Token yok — Login ekranından token girin",
    };
  }
  const rawUrl = path.startsWith("http") ? path : `${customApiBase()}/${path}`;
  const url = rawUrl.replace(/ /g, "%20").replace(/'/g, "%27");
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  };
  if (method === "PATCH" || method === "DELETE") {
    headers["If-Match"] = "*";
  }
  if (body !== null) {
    headers["Content-Type"] = "application/json";
  }
  try {
    const resp = await fetch(url, {
      method,
      headers,
      body: body ?? undefined,
    });
    const text = await resp.text();
    return { ok: resp.ok, httpCode: resp.status, body: text };
  } catch (e) {
    return {
      ok: false,
      httpCode: -1,
      body: `Hata: ${(e as Error).message}`,
    };
  }
}

export const get = (path: string): Promise<ApiResult> =>
  request("GET", path, null);

export const post = (path: string, body: string | null): Promise<ApiResult> =>
  request("POST", path, body ?? "");

export const patch = (path: string, body: string): Promise<ApiResult> =>
  request("PATCH", path, body);

export const del = (path: string): Promise<ApiResult> =>
  request("DELETE", path, null);

/** Tries the custom-API path first; on 404 falls back to the standard /api/v2.0 path. */
export async function getWithStandardFallback(
  customPath: string,
  standardPath?: string,
): Promise<ApiResult> {
  const r = await get(customPath);
  if (r.httpCode !== 404) return r;
  const sp = standardPath ?? customPath;
  return request("GET", `${standardApiBase()}/${sp}`, null);
}

/** Bound action POST .../{entitySet}({key})/Microsoft.NAV.{action} */
export async function boundAction(
  entitySet: string,
  key: string,
  action: string,
  body: string = "{}",
): Promise<ApiResult> {
  const keySegment =
    key.includes("=") || key.startsWith("'")
      ? key
      : `'${key.replace(/'/g, "''")}'`;
  return post(`${entitySet}(${keySegment})/Microsoft.NAV.${action}`, body);
}

// ---- Response helpers ----
export function parseValueArray(body: string): Record<string, unknown>[] {
  try {
    const obj = JSON.parse(body);
    if (obj && Array.isArray(obj.value)) return obj.value;
  } catch {
    // ignore
  }
  return [];
}

export function scalarValue(body: string): string {
  try {
    const obj = JSON.parse(body);
    return typeof obj.value === "string" ? obj.value : String(obj.value ?? "");
  } catch {
    return "";
  }
}

export function errorMessage(body: string): string {
  try {
    const obj = JSON.parse(body);
    const m = obj?.error?.message;
    if (typeof m === "string" && m.length > 0) return m;
  } catch {
    // ignore
  }
  return body.slice(0, 300);
}

// ---- First-string-not-blank helper (mirrors firstValue in mobile UI) ----
export function firstValue(
  obj: Record<string, unknown> | null | undefined,
  ...keys: string[]
): string {
  if (!obj) return "";
  for (const k of keys) {
    const v = obj[k];
    if (v !== null && v !== undefined && String(v).length > 0) return String(v);
  }
  return "";
}

// ---- Quick connection test ----
export const testConnection = (): Promise<ApiResult> =>
  get("licensePlates?$top=1");

// ---- Environment / company discovery ----
export async function discoverEnvironments(
  token: string,
): Promise<{ environment: string; companies: Company[] }[]> {
  const out: { environment: string; companies: Company[] }[] = [];
  for (const env of KNOWN_ENVIRONMENTS) {
    try {
      const resp = await fetch(companiesUrl(env), {
        headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      });
      if (!resp.ok) continue;
      const text = await resp.text();
      const arr = parseValueArray(text);
      const companies: Company[] = arr.map((c) => ({
        id: String(c.id ?? ""),
        name: String(c.name ?? ""),
        displayName: String(c.displayName ?? c.name ?? ""),
      }));
      if (companies.length > 0) out.push({ environment: env, companies });
    } catch {
      // skip env
    }
  }
  return out;
}
