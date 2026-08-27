import type { HttpRequest, InvocationContext, HttpResponseInit } from "@azure/functions";

type GhRelease = {
  tag_name: string;
  name?: string;
  body?: string;
  published_at: string;
  prerelease: boolean;
  assets: { name: string; browser_download_url: string }[];
};

const cache = { fetchedAt: 0, body: null as null | unknown[] };
const CACHE_TTL_MS = 5 * 60 * 1000;
const REPO = process.env.PORTAL_GH_REPO ?? "DynOpsBC/WMS";

export default async function releases(
  _request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  if (cache.body && Date.now() - cache.fetchedAt < CACHE_TTL_MS) {
    return { status: 200, jsonBody: cache.body };
  }

  const headers: Record<string, string> = { Accept: "application/vnd.github+json" };
  const token = process.env.PORTAL_GH_TOKEN;
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=20`, { headers });
  if (!response.ok) {
    context.warn(`GitHub releases fetch failed ${response.status}`);
    return { status: 502, jsonBody: { ok: false, error: "GitHub releases unavailable" } };
  }
  const raw = (await response.json()) as GhRelease[];
  const body = raw.map((r) => {
    const bcApp = r.assets.find((a) => a.name.endsWith(".app") || a.name.endsWith(".zip"));
    const apk = r.assets.find((a) => a.name.toLowerCase().endsWith(".apk"));
    const agentBins = r.assets
      .filter((a) => a.name.startsWith("bcwms-print-agent"))
      .map((a) => ({ os: detectOs(a.name), arch: detectArch(a.name), url: a.browser_download_url }));
    return {
      version: r.tag_name.replace(/^v/, ""),
      channel: r.prerelease ? "preview" : "stable",
      publishedAt: r.published_at,
      notes: r.body ?? "",
      bcAppUrl: bcApp?.browser_download_url,
      apkUrl: apk?.browser_download_url,
      agentBinaries: agentBins,
    };
  });
  cache.body = body;
  cache.fetchedAt = Date.now();
  return { status: 200, jsonBody: body };
}

function detectOs(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes("windows") || lower.endsWith(".exe")) return "windows";
  if (lower.includes("darwin") || lower.includes("mac")) return "macos";
  if (lower.includes("linux")) return "linux";
  return "unknown";
}

function detectArch(name: string): string {
  const lower = name.toLowerCase();
  if (lower.includes("arm64") || lower.includes("aarch64")) return "arm64";
  if (lower.includes("amd64") || lower.includes("x64") || lower.includes("x86_64")) return "amd64";
  return "unknown";
}
