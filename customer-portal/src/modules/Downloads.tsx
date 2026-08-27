import React from "react";

const downloads = [
  { label: "BC Extension (.app v1.10.0)", href: "https://github.com/DynOpsBC/WMS/releases/latest", desc: "Per-Tenant Extension paketi. BC Admin Center → Manage Extensions → Upload" },
  { label: "Android APK (sideload)", href: "https://github.com/DynOpsBC/WMS/releases/latest", desc: "Play Store dışı kurulum içindir. Cihaz ayarlarında 'Bilinmeyen kaynaklara izin ver' gerekir." },
  { label: "Print Agent (Windows x64)", href: "https://github.com/DynOpsBC/WMS/releases/latest", desc: "Self-Hosted Print Bridge agent'ı. NSSM servisi olarak kurulur." },
  { label: "Print Agent (macOS arm64)", href: "https://github.com/DynOpsBC/WMS/releases/latest", desc: "launchd plist ile root servisi olarak kurulur." },
  { label: "Print Agent (Linux x64)", href: "https://github.com/DynOpsBC/WMS/releases/latest", desc: "systemd unit ile kurulur." },
];

export function Downloads() {
  return (
    <div>
      <div className="docheader">
        <h2>İndir</h2>
        <div className="meta">Müşteri ortamına kurulacak tüm paketler tek bir yerde.</div>
      </div>
      <div className="list">
        {downloads.map((d) => (
          <div className="card" key={d.label}>
            <div className="row-between">
              <div>
                <div className="card-title">{d.label}</div>
                <div className="card-meta">{d.desc}</div>
              </div>
              <a className="primary" href={d.href} target="_blank" rel="noreferrer" style={{ padding: "8px 16px", borderRadius: "calc(var(--radius) - 4px)", color: "white", background: "hsl(var(--primary))", textDecoration: "none", fontWeight: 500 }}>
                İndir
              </a>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
