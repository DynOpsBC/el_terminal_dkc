import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { EmptyState, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function PostingTest() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [running, setRunning] = useState(false);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "postingTests?$orderby=sortOrder&$select=domain,description,status,detail,postedDocNo",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Posting test listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Posting test verisi yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} domain (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  async function runAll() {
    setRunning(true);
    setStatus("Tüm posting testleri çalışıyor...");
    const r = await BcApi.boundAction("postingTests", "1-MOVE", "runAll", "{}");
    setRunning(false);
    setStatus(
      r.ok
        ? `PASS: Tüm posting testleri çalıştırıldı (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) load();
  }

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading || running}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
        <button className="primary big" onClick={runAll} disabled={running}>
          {running ? "Çalışıyor..." : "▶ Tüm Postingleri Test Et"}
        </button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d, idx) => {
          const statusVal = String(d.status ?? "");
          const tone = statusVal === "Pass" || statusVal === "PASS" ? "ok" : statusVal === "Fail" || statusVal === "FAIL" ? "warn" : "neutral";
          return (
            <div key={`${d.domain}-${idx}`} className="card">
              <div className="row-between">
                <div className="card-title">{String(d.domain)} — {String(d.description ?? "")}</div>
                <Pill text={statusVal || "-"} tone={tone as "ok" | "warn" | "neutral"} />
              </div>
              <div className="card-meta">
                {String(d.detail ?? "")}
                {d.postedDocNo && ` · Doc: ${String(d.postedDocNo)}`}
              </div>
            </div>
          );
        })}
        {rows.length === 0 && !loading && (
          <EmptyState message="Posting test verisi yok. ▶ Tüm Postingleri Test Et ile çalıştır." />
        )}
      </div>
    </div>
  );
}
