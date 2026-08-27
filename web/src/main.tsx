import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import "./styles.css";
import * as BcApi from "./lib/bcApi";
import { SCREEN_TITLES, type Screen } from "./routes";
import { Login } from "./modules/Login";
import { Home } from "./modules/Home";
import { Receiving } from "./modules/Receiving";
import { Shipping } from "./modules/Shipping";
import { LicensePlate } from "./modules/LicensePlate";
import { Picking } from "./modules/Picking";
import { PutAway } from "./modules/PutAway";
import { Count } from "./modules/Count";
import { Movement } from "./modules/Movement";
import { Production } from "./modules/Production";
import { Assembly } from "./modules/Assembly";
import { Inquiry } from "./modules/Inquiry";
import { PostingTest } from "./modules/PostingTest";
import { Quality } from "./modules/Quality";
import { QualityManagement } from "./modules/QualityManagement";
import { Printers } from "./modules/Printers";
import { SelfTest } from "./modules/SelfTest";
import { UpdateToast } from "./ui/UpdateToast";
import { initServiceWorker } from "./lib/updateNotifier";

type Navigate = (s: Screen) => void;

// Cross-module navigator — picking/put-away QC banner can deep-link to QM.
let appNavigator: Navigate | null = null;
export function navigateTo(s: Screen) {
  appNavigator?.(s);
}

function App() {
  const [screen, setScreen] = useState<Screen>(BcApi.hasToken() ? "home" : "login");
  const [conn, setConn] = useState<"unknown" | "ok" | "bad">("unknown");

  useEffect(() => {
    appNavigator = setScreen;
    return () => { appNavigator = null; };
  }, []);

  useEffect(() => {
    if (screen === "login") return;
    let cancelled = false;
    (async () => {
      const r = await BcApi.testConnection();
      if (!cancelled) setConn(r.ok ? "ok" : "bad");
    })();
    return () => { cancelled = true; };
  }, [screen]);

  function signOut() {
    BcApi.clearToken();
    setScreen("login");
  }

  if (screen === "login") {
    return <Login onSignedIn={() => setScreen("home")} />;
  }

  return (
    <div className="shell">
      <header className="topbar">
        <h1>
          {screen !== "home" && (
            <button className="ghost" onClick={() => setScreen("home")}>‹ Menü</button>
          )}
          <span>🏭 BCWMS</span>
          <span className="crumb">/ {SCREEN_TITLES[screen]}</span>
        </h1>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span style={{ fontSize: 11, color: "var(--text-muted)" }}>
            BC: {BcApi.getEnvironment()} / {BcApi.getCompanyName()}
          </span>
          <span className={`badge-connect ${conn === "ok" ? "ok" : conn === "bad" ? "bad" : ""}`}>
            {conn === "ok" ? "🟢 Bağlı" : conn === "bad" ? "🔴 Bağlı değil" : "⏳ Bağlanıyor"}
          </span>
          <button className="ghost small" onClick={signOut}>Çıkış</button>
        </div>
      </header>
      <main className="content">
        {screen === "home" && <Home navigate={setScreen} />}
        {screen === "receiving" && <Receiving />}
        {screen === "shipping" && <Shipping />}
        {screen === "lp" && <LicensePlate />}
        {screen === "picking" && <Picking />}
        {screen === "putaway" && <PutAway />}
        {screen === "count" && <Count />}
        {(screen === "adhoc" || screen === "directed") && (
          <Movement initialTab={screen === "directed" ? "directed" : "adhoc"} />
        )}
        {screen === "production" && <Production />}
        {screen === "assembly" && <Assembly />}
        {(screen === "inquiry" || screen === "binInquiry") && (
          <Inquiry initialTab={screen === "binInquiry" ? "bin" : "item"} />
        )}
        {screen === "posting" && <PostingTest />}
        {screen === "quality" && <Quality />}
        {screen === "qms" && <QualityManagement />}
        {screen === "printers" && <Printers />}
        {screen === "selfTest" && <SelfTest />}
      </main>
      <UpdateToast />
    </div>
  );
}

const root = document.getElementById("root");
if (root) {
  void initServiceWorker();
  createRoot(root).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  );
}
