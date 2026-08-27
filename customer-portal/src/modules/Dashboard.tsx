import React from "react";
import * as PortalApi from "../lib/portalApi.js";

export function Dashboard({ tenantId, accountEmail }: { tenantId: string; accountEmail: string | null }) {
  const [summary, setSummary] = React.useState<PortalApi.LicenseSummary | null>(null);
  const [loading, setLoading] = React.useState(false);
  const [err, setErr] = React.useState("");

  React.useEffect(() => {
    if (!tenantId) return;
    setLoading(true);
    PortalApi.getMyLicense(tenantId)
      .then(setSummary)
      .catch((e: Error) => setErr(e.message))
      .finally(() => setLoading(false));
  }, [tenantId]);

  if (!tenantId) return <div className="empty">Tenant id okunamadı. Lütfen oturum açın.</div>;
  if (loading) return <div className="empty">Yükleniyor…</div>;
  if (err) return <div className="banner-warn">Hata: {err}</div>;

  const active = summary?.active;

  return (
    <div>
      <div className="docheader">
        <h2>Hoş geldin{accountEmail ? `, ${accountEmail}` : ""}</h2>
        <div className="meta">Tenant id: {tenantId}</div>
      </div>

      {!active ? (
        <div className="card">
          <div className="card-title">Aktif lisans yok</div>
          <div className="card-meta">
            "Lisans" sekmesinden yeni bir lisans satın al veya mevcut bir
            anahtarı kontrol et. Şu anda BC ortamlarınız <b>Essentials</b>
            kapsamında çalışıyor.
          </div>
        </div>
      ) : (
        <div className="detail-grid">
          <div className="card">
            <div className="card-title">Lisans</div>
            <div className="card-meta">Aktif sürüm, tier ve seat sayısı.</div>
            <ul style={{ marginTop: 12, paddingLeft: 16 }}>
              <li><b>Tier:</b> {active.tier}</li>
              <li><b>Seats:</b> {active.seats}</li>
              <li><b>Yayınlandı:</b> {new Date(active.issuedAt).toLocaleDateString()}</li>
              <li><b>Bitiş:</b> {new Date(active.validUntil).toLocaleDateString()}</li>
              <li><b>Durum:</b> <span className={`pill ${active.status === "active" ? "ok" : "warn"}`}>{active.status}</span></li>
            </ul>
          </div>
          <div className="card">
            <div className="card-title">Sonraki adım</div>
            <div className="card-meta">
              Yeni bir sürüm yayınlandığında "Sürümler" sekmesinde "Şimdi
              yükselt" butonuyla BC ortamına push edebilirsiniz. Sorun
              durumunda DynOps destek otomatik uyarı alır.
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
