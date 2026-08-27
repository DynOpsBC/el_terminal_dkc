import React from "react";
import * as PortalApi from "../lib/portalApi.js";

export function License({ tenantId, accountEmail }: { tenantId: string; accountEmail: string | null }) {
  const [summary, setSummary] = React.useState<PortalApi.LicenseSummary | null>(null);
  const [adminToken, setAdminToken] = React.useState("");
  const [tier, setTier] = React.useState<"Essentials" | "Advanced" | "Enterprise">("Advanced");
  const [seats, setSeats] = React.useState(20);
  const [validUntil, setValidUntil] = React.useState(() => {
    const d = new Date();
    d.setFullYear(d.getFullYear() + 1);
    return d.toISOString().slice(0, 10);
  });
  const [email, setEmail] = React.useState("");
  const [issuedKey, setIssuedKey] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState("");

  React.useEffect(() => {
    if (!tenantId) return;
    PortalApi.getMyLicense(tenantId).then(setSummary).catch(() => undefined);
  }, [tenantId]);

  React.useEffect(() => { setEmail(accountEmail ?? ""); }, [accountEmail]);

  async function issue() {
    setBusy(true); setErr(""); setIssuedKey("");
    try {
      const result = await PortalApi.issueLicense({
        tenantId,
        tier,
        seats,
        validUntil,
        customerEmail: email,
        adminToken,
        replaceActive: true,
      });
      setIssuedKey(result.key);
      const next = await PortalApi.getMyLicense(tenantId);
      setSummary(next);
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="docheader">
        <h2>Lisans</h2>
        <div className="meta">DynOps personeli tarafından imzalanmış JWT lisansı görüntüle veya yenisini iste.</div>
      </div>

      <div className="detail-grid">
        <div className="card">
          <div className="card-title">Aktif lisans</div>
          {summary?.active ? (
            <ul style={{ paddingLeft: 16, marginTop: 12 }}>
              <li><b>Tier:</b> {summary.active.tier}</li>
              <li><b>Seats:</b> {summary.active.seats}</li>
              <li><b>Email:</b> {summary.active.email}</li>
              <li><b>Yayınlandı:</b> {new Date(summary.active.issuedAt).toLocaleString()}</li>
              <li><b>Bitiş:</b> {new Date(summary.active.validUntil).toLocaleString()}</li>
              <li><b>Durum:</b> {summary.active.status}</li>
            </ul>
          ) : (
            <div className="card-meta">Aktif lisans yok.</div>
          )}
        </div>

        <div className="card">
          <div className="card-title">Yeni lisans iste / yenile</div>
          <div className="card-meta">
            DynOps tarafında geçerli bir admin token gerekir; satış ekibi bunu sağlar.
          </div>
          <div style={{ marginTop: 12, display: "grid", gap: 10 }}>
            <label className="field">DynOps Admin Token
              <input value={adminToken} onChange={(e) => setAdminToken(e.target.value)} placeholder="X-Bcwms-Admin-Token" />
            </label>
            <label className="field">Tier
              <select value={tier} onChange={(e) => setTier(e.target.value as typeof tier)} aria-label="Tier">
                <option value="Essentials">Essentials</option>
                <option value="Advanced">Advanced</option>
                <option value="Enterprise">Enterprise</option>
              </select>
            </label>
            <label className="field">Seats
              <input type="number" min={1} value={seats} onChange={(e) => setSeats(Number(e.target.value))} />
            </label>
            <label className="field">Bitiş tarihi
              <input type="date" value={validUntil} onChange={(e) => setValidUntil(e.target.value)} />
            </label>
            <label className="field">İletişim e-postası
              <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" />
            </label>
            <button className="primary" disabled={busy || !adminToken} onClick={issue}>
              {busy ? "..." : "Lisans üret"}
            </button>
            {err && <div className="banner-warn">Hata: {err}</div>}
            {issuedKey && (
              <div>
                <div className="card-title" style={{ marginTop: 12 }}>Yeni JWT</div>
                <div className="card-meta">Anahtarı şimdi kopyalayın; sayfa kapanınca geri alamazsınız.</div>
                <textarea
                  readOnly
                  value={issuedKey}
                  rows={5}
                  style={{ marginTop: 6, fontFamily: "JetBrains Mono, monospace", fontSize: 11 }}
                  aria-label="License JWT"
                />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
