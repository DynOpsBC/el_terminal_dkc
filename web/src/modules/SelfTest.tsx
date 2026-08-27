import React, { useMemo, useState } from "react";
import * as BcApi from "../lib/bcApi";

/**
 * Web app sağlık paneli. Müşteri ortamı kurulumundan sonra
 * "her şey çalışıyor mu?" diye tek dokunuşla doğrulanmak üzere
 * 10 ayrı check'i sırayla yürütür ve PASS/FAIL/SKIP raporu üretir.
 *
 * Mobil tarafındaki SelfTestModule.kt ile aynı katalogu paylaşır —
 * eklenen yeni bir check her iki platformda da güncellenmeli.
 */

type CheckStatus = "pending" | "running" | "pass" | "fail" | "skip";

interface CheckResult {
  id: string;
  title: string;
  status: CheckStatus;
  message: string;
  durationMs: number;
}

const INITIAL_CHECKS: CheckResult[] = [
  { id: "token", title: "BC token saklanmış mı?", status: "pending", message: "", durationMs: 0 },
  { id: "bc_warehouse", title: "warehouse/v2.0 API ulaşılabilir mi?", status: "pending", message: "", durationMs: 0 },
  { id: "bc_standard", title: "Standart items fallback çalışıyor mu?", status: "pending", message: "", durationMs: 0 },
  { id: "item_inventory", title: "ItemApi inventory FlowField calc çalışıyor mu?", status: "pending", message: "", durationMs: 0 },
  { id: "bin_contents", title: "BinContentApi (page 72097) çalışıyor mu?", status: "pending", message: "", durationMs: 0 },
  { id: "lp_templates", title: "LP templates seed edilmiş mi?", status: "pending", message: "", durationMs: 0 },
  { id: "quality_orders", title: "qualityOrders API çalışıyor mu?", status: "pending", message: "", durationMs: 0 },
  { id: "service_worker", title: "PWA service worker kayıtlı mı?", status: "pending", message: "", durationMs: 0 },
  { id: "local_storage", title: "localStorage yazılabilir mi?", status: "pending", message: "", durationMs: 0 },
  { id: "token_age", title: "Token süresi geçerli mi?", status: "pending", message: "", durationMs: 0 },
];

const STATUS_META: Record<CheckStatus, { icon: string; color: string }> = {
  pending: { icon: "·", color: "var(--text-muted)" },
  running: { icon: "⏳", color: "#1565C0" },
  pass: { icon: "✅", color: "#2E7D32" },
  fail: { icon: "❌", color: "#C62828" },
  skip: { icon: "⏭", color: "#6A6A6A" },
};

export function SelfTest() {
  const [results, setResults] = useState<CheckResult[]>(INITIAL_CHECKS);
  const [running, setRunning] = useState(false);

  const update = (id: string, patch: Partial<CheckResult>) =>
    setResults((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  async function timed(
    id: string,
    block: () => Promise<{ status: CheckStatus; message: string }>,
  ): Promise<void> {
    update(id, { status: "running", message: "" });
    const start = performance.now();
    try {
      const { status, message } = await block();
      update(id, { status, message, durationMs: Math.round(performance.now() - start) });
    } catch (err) {
      update(id, {
        status: "fail",
        message: `exception: ${(err as Error).message ?? String(err)}`,
        durationMs: Math.round(performance.now() - start),
      });
    }
  }

  async function runAll() {
    if (running) return;
    setRunning(true);
    setResults(INITIAL_CHECKS);

    const hasToken = BcApi.hasToken();

    await timed("token", async () =>
      hasToken
        ? { status: "pass", message: "Bağlantı tokenı kayıtlı" }
        : { status: "fail", message: "Token yok — Giriş ekranına dönün" },
    );

    await timed("bc_warehouse", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get("licensePlates?$top=1");
      return r.ok
        ? { status: "pass", message: `warehouse/v2.0 OK (HTTP ${r.httpCode})` }
        : { status: "fail", message: `HTTP ${r.httpCode}` };
    });

    await timed("bc_standard", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.getWithStandardFallback("items?$top=1");
      return r.ok
        ? { status: "pass", message: `items endpoint OK (HTTP ${r.httpCode})` }
        : { status: "fail", message: `HTTP ${r.httpCode}` };
    });

    await timed("item_inventory", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get(
        "items?$top=1&$select=no,inventory,quantityOnPurchOrder,quantityOnSalesOrder",
      );
      if (!r.ok) return { status: "fail", message: `HTTP ${r.httpCode}` };
      const first = BcApi.parseValueArray(r.body)[0];
      if (!first) return { status: "skip", message: "Hiç item yok" };
      if (!("inventory" in first)) {
        return { status: "fail", message: "inventory field yok — ItemApi güncel mi?" };
      }
      return {
        status: "pass",
        message: `inventory field döner (${String(first.no)}=${String(first.inventory)})`,
      };
    });

    await timed("bin_contents", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get("binContents?$top=1");
      return r.ok
        ? { status: "pass", message: "binContents endpoint OK" }
        : {
            status: "fail",
            message: `HTTP ${r.httpCode} — DOPSWHS BinContent API publish edildi mi?`,
          };
    });

    await timed("lp_templates", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get("licensePlateTemplates?$top=10&$select=code");
      if (!r.ok) return { status: "fail", message: `HTTP ${r.httpCode}` };
      const codes = BcApi.parseValueArray(r.body);
      if (codes.length === 0) {
        return { status: "fail", message: "Hiç LP template yok — Setup gerekli" };
      }
      return { status: "pass", message: `${codes.length} template (${String(codes[0]?.code)}...)` };
    });

    await timed("quality_orders", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get("qualityOrders?$top=1");
      return r.ok
        ? { status: "pass", message: "qualityOrders endpoint OK" }
        : { status: "fail", message: `HTTP ${r.httpCode}` };
    });

    await timed("service_worker", async () => {
      if (!("serviceWorker" in navigator)) {
        return { status: "skip", message: "Tarayıcı service worker desteklemiyor" };
      }
      const reg = await navigator.serviceWorker.getRegistration();
      if (!reg) return { status: "fail", message: "PWA service worker kayıtlı değil" };
      return { status: "pass", message: `scope: ${reg.scope}` };
    });

    await timed("local_storage", async () => {
      try {
        const probe = `__bcwms_self_test_${Date.now()}__`;
        localStorage.setItem(probe, "1");
        const echoed = localStorage.getItem(probe);
        localStorage.removeItem(probe);
        return echoed === "1"
          ? { status: "pass", message: "localStorage R/W OK" }
          : { status: "fail", message: "localStorage echo başarısız" };
      } catch (e) {
        return { status: "fail", message: `localStorage erişimi yok: ${(e as Error).message}` };
      }
    });

    await timed("token_age", async () => {
      if (!hasToken) return { status: "skip", message: "Token gerek" };
      const r = await BcApi.get("licensePlates?$top=1");
      if (r.httpCode === 401) {
        return { status: "fail", message: "Token süresi dolmuş — yeniden giriş yapın" };
      }
      if (r.ok) return { status: "pass", message: `Token geçerli (HTTP ${r.httpCode})` };
      return { status: "skip", message: `Belirsiz (HTTP ${r.httpCode})` };
    });

    setRunning(false);
  }

  const summary = useMemo(() => {
    const pass = results.filter((r) => r.status === "pass").length;
    const fail = results.filter((r) => r.status === "fail").length;
    const skip = results.filter((r) => r.status === "skip").length;
    const pending = results.length - pass - fail - skip;
    return { pass, fail, skip, pending, total: results.length };
  }, [results]);

  const overallBg = running
    ? "#E3F2FD"
    : summary.fail > 0
      ? "#FFEBEE"
      : summary.pass > 0 && summary.pass + summary.skip === summary.total
        ? "#E8F5E9"
        : "var(--bg-elevated, #f6f6f6)";

  return (
    <div style={{ padding: 16 }}>
      <div
        style={{
          background: overallBg,
          border: "1px solid var(--border, #e0e0e0)",
          borderRadius: 12,
          padding: 14,
          marginBottom: 12,
        }}
      >
        <div style={{ fontWeight: 700, fontSize: 18 }}>Sistem Sağlığı</div>
        <div style={{ fontSize: 12, color: "var(--text-muted)" }}>
          Web app + BC + PWA + localStorage probe'ları
        </div>
        <div style={{ marginTop: 8, fontWeight: 500, fontSize: 14 }}>
          {summary.pass} ✅ &nbsp;·&nbsp; {summary.fail} ❌ &nbsp;·&nbsp; {summary.skip} ⏭ &nbsp;·&nbsp; {summary.pending} ⏳
        </div>
      </div>
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <button
          onClick={runAll}
          disabled={running}
          style={{
            flex: 1,
            padding: "10px 14px",
            fontWeight: 700,
            background: running ? "var(--bg-muted, #ccc)" : "#1565C0",
            color: "#fff",
            border: "none",
            borderRadius: 8,
            cursor: running ? "default" : "pointer",
          }}
        >
          {running ? "Çalışıyor…" : "▶︎ Tümünü Çalıştır"}
        </button>
        <button
          onClick={() => setResults(INITIAL_CHECKS)}
          disabled={running}
          style={{
            flex: 1,
            padding: "10px 14px",
            border: "1px solid var(--border, #ccc)",
            background: "transparent",
            borderRadius: 8,
            cursor: running ? "default" : "pointer",
          }}
        >
          Sıfırla
        </button>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {results.map((r) => {
          const meta = STATUS_META[r.status];
          return (
            <div
              key={r.id}
              style={{
                background: "var(--bg-card, #fff)",
                border: "1px solid var(--border, #e0e0e0)",
                borderRadius: 8,
                padding: "10px 12px",
                display: "flex",
                alignItems: "center",
                gap: 12,
              }}
            >
              <div style={{ fontSize: 18 }}>{meta.icon}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, color: meta.color }}>{r.title}</div>
                {r.message && (
                  <div style={{ fontSize: 11, color: "var(--text-muted)" }}>{r.message}</div>
                )}
              </div>
              {r.durationMs > 0 && (
                <div style={{ fontSize: 10, color: "var(--text-muted)" }}>{r.durationMs}ms</div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
