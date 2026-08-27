import React from "react";
import * as PortalApi from "../lib/portalApi.js";

export function Releases({ tenantId }: { tenantId: string }) {
  const [releases, setReleases] = React.useState<PortalApi.ReleaseEntry[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [err, setErr] = React.useState("");
  const [busy, setBusy] = React.useState<string | null>(null);
  const [msg, setMsg] = React.useState("");

  React.useEffect(() => {
    setLoading(true);
    PortalApi.getReleases()
      .then((r) => setReleases(r))
      .catch((e: Error) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  async function upgrade(version: string) {
    if (!confirm(`BC ortamını ${version} sürümüne yükseltmek istediğinizden emin misiniz?`)) return;
    const envName = prompt("Hedef BC environment (örn: Production / SandboxUS):", "Production");
    if (!envName) return;
    setBusy(version);
    setMsg("");
    try {
      await PortalApi.triggerBcUpdate({ tenantId, environment: envName, version });
      setMsg(`Update tetiklendi → ${version}. BC Admin Center sırasında ilerleyecek.`);
    } catch (e) {
      setMsg(`Hata: ${(e as Error).message}`);
    } finally {
      setBusy(null);
    }
  }

  if (loading) return <div className="empty">Yükleniyor…</div>;
  if (err) return <div className="banner-warn">Hata: {err}</div>;
  if (releases.length === 0) return <div className="empty">Henüz yayınlanmış sürüm yok.</div>;

  return (
    <div>
      <div className="docheader">
        <h2>Sürümler</h2>
        <div className="meta">Yayınlanan sürümler, sürüm notları ve BC'ye doğrudan yükseltme.</div>
      </div>
      {msg && <div className="banner-warn" style={{ borderColor: "hsl(var(--primary))" }}>{msg}</div>}
      <div className="list">
        {releases.map((release) => (
          <div key={`${release.version}-${release.channel}`} className="card">
            <div className="row-between">
              <div>
                <div className="card-title">
                  v{release.version} {release.channel === "preview" && <span className="pill warn">preview</span>}
                </div>
                <div className="card-meta">
                  Yayınlandı: {new Date(release.publishedAt).toLocaleDateString()}
                </div>
              </div>
              <div style={{ display: "flex", gap: 8 }}>
                <button
                  className="primary"
                  disabled={busy === release.version}
                  onClick={() => upgrade(release.version)}
                >
                  {busy === release.version ? "..." : "🚀 Şimdi yükselt"}
                </button>
              </div>
            </div>
            <pre style={{ margin: "12px 0 0 0", fontFamily: "inherit", whiteSpace: "pre-wrap", fontSize: 13 }}>
              {release.notes}
            </pre>
          </div>
        ))}
      </div>
    </div>
  );
}
