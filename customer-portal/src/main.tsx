import React from "react";
import { createRoot } from "react-dom/client";
import { MsalProvider, AuthenticatedTemplate, UnauthenticatedTemplate, useMsal, useAccount } from "@azure/msal-react";
import { msalInstance, loginRequest } from "./lib/msalConfig.js";
import { Dashboard } from "./modules/Dashboard.js";
import { Releases } from "./modules/Releases.js";
import { License } from "./modules/License.js";
import { Downloads } from "./modules/Downloads.js";
import "./styles.css";

type View = "dashboard" | "releases" | "license" | "downloads";

function PortalShell() {
  const { instance, accounts } = useMsal();
  const account = useAccount(accounts[0] ?? null);
  const [view, setView] = React.useState<View>("dashboard");
  const tenantId = (account?.tenantId ?? account?.idTokenClaims?.tid ?? "") as string;

  return (
    <div className="shell">
      <header className="topbar">
        <h1>
          <span>🎛 BCWMS Portal</span>
          <span className="crumb">/ {viewTitle(view)}</span>
        </h1>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span style={{ fontSize: 11, color: "var(--text-muted)" }}>
            {account?.username ?? "—"} · tenant {(tenantId || "?").slice(0, 8)}
          </span>
          <button className="ghost small" onClick={() => instance.logoutRedirect()}>Çıkış</button>
        </div>
      </header>
      <nav className="topbar" style={{ minHeight: 44, paddingTop: 6, paddingBottom: 6 }}>
        <div className="tabs">
          {(["dashboard", "releases", "license", "downloads"] as View[]).map((v) => (
            <button key={v} className={`tab ${view === v ? "active" : ""}`} onClick={() => setView(v)}>
              {viewTitle(v)}
            </button>
          ))}
        </div>
      </nav>
      <main className="content">
        {view === "dashboard" && <Dashboard tenantId={tenantId} accountEmail={account?.username ?? null} />}
        {view === "releases" && <Releases tenantId={tenantId} />}
        {view === "license" && <License tenantId={tenantId} accountEmail={account?.username ?? null} />}
        {view === "downloads" && <Downloads />}
      </main>
    </div>
  );
}

function viewTitle(view: View): string {
  switch (view) {
    case "dashboard": return "Dashboard";
    case "releases": return "Sürümler";
    case "license": return "Lisans";
    case "downloads": return "İndir";
  }
}

function LoginCard() {
  const { instance } = useMsal();
  return (
    <div className="login-shell">
      <div className="login-card">
        <h1>BCWMS Customer Portal</h1>
        <p className="sub">
          Microsoft hesabınızla oturum açın. Aynı tenant'taki Business Central
          ortamlarınızın lisansını ve sürümünü tek yerden yönetin.
        </p>
        <div style={{ marginTop: 16, display: "flex", justifyContent: "center" }}>
          <button className="primary big" onClick={() => instance.loginRedirect(loginRequest)}>
            Microsoft hesabı ile giriş yap
          </button>
        </div>
        <div className="helper" style={{ marginTop: 24, textAlign: "center" }}>
          Sorun yaşıyor musunuz? <a href="mailto:support@dynops.com">support@dynops.com</a>
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <MsalProvider instance={msalInstance}>
      <AuthenticatedTemplate>
        <PortalShell />
      </AuthenticatedTemplate>
      <UnauthenticatedTemplate>
        <LoginCard />
      </UnauthenticatedTemplate>
    </MsalProvider>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
