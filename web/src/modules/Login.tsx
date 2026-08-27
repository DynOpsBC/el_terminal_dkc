import React, { useState } from "react";
import {
  KNOWN_ENVIRONMENTS,
  discoverEnvironments,
  saveToken,
  setCompany,
  setEnvironment,
  testConnection,
} from "../lib/bcApi";

interface LoginProps {
  onSignedIn: () => void;
}

export function Login({ onSignedIn }: LoginProps) {
  const [token, setToken] = useState("");
  const [env, setEnv] = useState(KNOWN_ENVIRONMENTS[0]);
  const [companyId, setCompanyId] = useState(
    "1534369d-f248-f111-b478-7c1e521cfdf0",
  );
  const [companyName, setCompanyName] = useState("CRONUS USA, Inc.");
  const [discovered, setDiscovered] = useState<
    { environment: string; companies: { id: string; name: string; displayName: string }[] }[]
  >([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function discover() {
    if (token.trim().length < 50) {
      setStatus("HATA: Token alanı boş ya da çok kısa.");
      return;
    }
    setBusy(true);
    setStatus("Ortamlar taranıyor...");
    try {
      const list = await discoverEnvironments(token.trim());
      setDiscovered(list);
      if (list.length === 0) {
        setStatus("HATA: Hiçbir ortamda şirket bulunamadı. Token geçerli mi?");
      } else {
        setStatus(`PASS: ${list.length} ortam, ${list.reduce((a, b) => a + b.companies.length, 0)} şirket bulundu.`);
        // pre-select first env/company
        const e = list[0];
        setEnv(e.environment);
        if (e.companies.length > 0) {
          setCompanyId(e.companies[0].id);
          setCompanyName(e.companies[0].displayName);
        }
      }
    } catch (e) {
      setStatus(`HATA: ${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  async function signIn() {
    if (token.trim().length < 50) {
      setStatus("HATA: Geçerli bir token girin.");
      return;
    }
    setBusy(true);
    setStatus("Bağlantı test ediliyor...");
    saveToken(token);
    setEnvironment(env);
    setCompany(companyId, companyName);
    const r = await testConnection();
    setBusy(false);
    if (r.ok) {
      setStatus("PASS: BC bağlantısı OK — yönlendiriliyor...");
      setTimeout(() => onSignedIn(), 400);
    } else {
      setStatus(`HATA: BC bağlantısı başarısız (HTTP ${r.httpCode}). Token / env / şirket eşleşmiyor olabilir.`);
    }
  }

  return (
    <div className="login-shell">
      <div className="login-card">
        <h1>🏭 BCWMS Workstation</h1>
        <div className="sub">
          Business Central WMS — masaüstü kontrol istasyonu.
          AAD token ile bağlanın, ortam + şirketi seçin, çalışmaya başlayın.
        </div>

        <label className="field">AAD Access Token</label>
        <textarea
          value={token}
          onChange={(e) => setToken(e.target.value)}
          placeholder="eyJhbGciOiJSUzI1NiIs… (az account get-access-token --resource https://api.businesscentral.dynamics.com)"
        />
        <div className="helper">
          Terminal komutu (panoya kopyalanır):
          <pre className="code-block">{`# macOS
az account get-access-token \\
  --resource "https://api.businesscentral.dynamics.com" \\
  --query accessToken -o tsv | pbcopy

# Windows (PowerShell)
az account get-access-token \`
  --resource "https://api.businesscentral.dynamics.com" \`
  --query accessToken -o tsv | Set-Clipboard`}</pre>
          <details>
            <summary>📖 Token nasıl alınır? (3 yöntem)</summary>
            <ul>
              <li><b>az CLI</b> (her platform): yukarıdaki komut. İlk kez: <code>az login --tenant 7fa2357e-26f2-4174-8e16-a713981356b8</code></li>
              <li><b>PowerShell + MSAL.PS</b> (Windows): <code>Get-MsalToken … | Set-Clipboard</code></li>
              <li><b>Device Code</b> (tarayıcısız): curl ile <code>/oauth2/v2.0/devicecode</code></li>
            </ul>
            <p>
              Tam dokümantasyon:{" "}
              <a
                href="https://github.com/DynOpsBC/WMS/blob/main/docs/wms-token-generation.md"
                target="_blank"
                rel="noopener noreferrer"
              >
                docs/wms-token-generation.md
              </a>{" "}
              · Token ömrü ~1 saat · BC Role Center → "WMS Token Help" sayfası BC client'tan aynı rehberi gösterir.
            </p>
          </details>
        </div>

        <div className="row" style={{ marginTop: 12 }}>
          <button className="outline" onClick={discover} disabled={busy}>
            🔎 Ortamları Keşfet
          </button>
        </div>

        <hr className="hr" />

        <div className="row">
          <div>
            <label className="field">Ortam</label>
            <select value={env} onChange={(e) => setEnv(e.target.value)}>
              {(discovered.length > 0
                ? discovered.map((d) => d.environment)
                : KNOWN_ENVIRONMENTS
              ).map((e) => (
                <option key={e} value={e}>{e}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="field">Şirket</label>
            <select
              value={companyId}
              onChange={(e) => {
                const id = e.target.value;
                setCompanyId(id);
                const found = discovered
                  .flatMap((d) => d.companies)
                  .find((c) => c.id === id);
                setCompanyName(found?.displayName ?? "");
              }}
            >
              {(discovered.find((d) => d.environment === env)?.companies ?? [
                { id: companyId, name: companyName, displayName: companyName },
              ]).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.displayName}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ marginTop: 20 }}>
          <button className="primary full big" onClick={signIn} disabled={busy}>
            {busy ? "…" : "🔓 Bağlan"}
          </button>
        </div>

        {status && (
          <div
            className={`status ${
              status.startsWith("PASS") ? "ok" : status.startsWith("HATA") ? "err" : ""
            }`}
            style={{ marginTop: 12 }}
          >
            {status}
          </div>
        )}
      </div>
    </div>
  );
}
