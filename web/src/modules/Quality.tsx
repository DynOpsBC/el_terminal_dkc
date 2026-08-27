import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { EmptyState, Field, Modal, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

const REASONS = ["DAMAGED", "WRONGITEM", "EXPIRED", "CONTAMINATED", "SPEC-FAIL"];

export function Quality() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [inspect, setInspect] = useState<Row | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "qualityOrders?$top=50&$orderby=no&$select=no,sourceType,sourceNo,itemNo,itemDescription,quantity,sampleSize,status,inspector,resultNotes,quarantineBin",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Quality liste alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: Kalite emri yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} quality order (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => {
          const sval = String(d.status ?? "");
          const tone = sval === "Passed" || sval === "Pass" ? "ok" : sval === "Failed" || sval === "Fail" ? "warn" : "neutral";
          return (
            <div key={String(d.no)} className="card clickable" onClick={() => setInspect(d)}>
              <div className="row-between">
                <div className="card-title">{String(d.no)} · {String(d.itemNo)}</div>
                <Pill text={sval || "Open"} tone={tone as "ok" | "warn" | "neutral"} />
              </div>
              <div className="card-meta">
                {String(d.itemDescription ?? "")}
                <br />
                Kaynak: {BcApi.firstValue(d, "sourceType")}/{BcApi.firstValue(d, "sourceNo")} · Numune: {Number(d.sampleSize ?? 0)} / {Number(d.quantity ?? 0)}
                {d.inspector && ` · Denetçi: ${BcApi.firstValue(d, "inspector")}`}
              </div>
            </div>
          );
        })}
        {rows.length === 0 && !loading && <EmptyState message="Açık kalite emri yok." />}
      </div>
      {inspect && (
        <InspectModal
          order={inspect}
          onClose={() => setInspect(null)}
          onResult={async (passed, reason, notes, quarantineBin) => {
            const no = String(inspect.no);
            setInspect(null);
            setLoading(true);
            setStatus("Sonuç kaydediliyor...");
            const body = passed
              ? JSON.stringify({ inspector: "WEB", notes })
              : JSON.stringify({ inspector: "WEB", reasonCode: reason, notes, quarantineBin });
            const r = await BcApi.boundAction("qualityOrders", no, passed ? "pass" : "fail", body);
            setLoading(false);
            setStatus(
              r.ok
                ? `PASS: ${no} → ${passed ? "KABUL" : "RED"} (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) load();
          }}
        />
      )}
    </div>
  );
}

function InspectModal({
  order,
  onClose,
  onResult,
}: {
  order: Row;
  onClose: () => void;
  onResult: (passed: boolean, reason: string, notes: string, quarantineBin: string) => void;
}) {
  const [notes, setNotes] = useState("");
  const [reason, setReason] = useState(REASONS[0]);
  const [quarantine, setQuarantine] = useState("QUARANTINE");

  return (
    <Modal
      title={`Kalite Denetimi — ${order.no}`}
      meta={`${order.itemNo} — ${order.itemDescription ?? ""} · Numune: ${Number(order.sampleSize ?? 0)} / ${Number(order.quantity ?? 0)}`}
      onClose={onClose}
    >
      <Field label="Notlar" value={notes} onChange={setNotes} placeholder="Denetim gözlemleri" />

      <div className="mt12">
        <label className="field" htmlFor="quality-reason">RED Sebebi (sadece fail için)</label>
        <select
          id="quality-reason"
          title="Red sebep kodu"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        >
          {REASONS.map((r) => (
            <option key={r} value={r}>{r}</option>
          ))}
        </select>
      </div>

      <div className="mt12">
        <Field label="Karantina Bin (red için)" value={quarantine} onChange={setQuarantine} placeholder="QUARANTINE" />
      </div>

      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onResult(false, reason, notes.trim(), quarantine.trim())}
        >
          ❌ RED
        </button>
        <button
          className="primary"
          onClick={() => onResult(true, "", notes.trim(), "")}
        >
          ✅ KABUL
        </button>
      </div>
    </Modal>
  );
}
