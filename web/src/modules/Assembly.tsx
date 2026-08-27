import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { DocHeader, EmptyState, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function Assembly() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "assemblies?$top=30&$select=no,documentType,status,itemNo,description,quantity,remainingQuantity,locationCode,binCode,dueDate&$filter=documentType eq 'Order'",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Assembly listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: Açık assembly order yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} assembly order (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <AssemblyDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
  }

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>{loading ? "..." : "🔄 Yenile"}</button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => (
          <div key={String(d.no)} className="card clickable" onClick={() => setSelected(String(d.no))}>
            <div className="row-between">
              <div className="card-title">
                {String(d.no)} · {String(d.itemNo)}
              </div>
              <Pill text={String(d.status ?? "")} tone={String(d.status) === "Released" ? "ok" : "neutral"} />
            </div>
            <div className="card-meta">
              {String(d.description ?? "")}
              <br />
              Qty: {Number(d.quantity ?? 0)} · Kalan: {Number(d.remainingQuantity ?? 0)} · {BcApi.firstValue(d, "locationCode") || "-"}/{BcApi.firstValue(d, "binCode") || "-"} · Due: {BcApi.firstValue(d, "dueDate") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <EmptyState message="Açık assembly order yok." />}
      </div>
    </div>
  );
}

function AssemblyDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  const key = `documentType='Order',no='${no}'`;

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`assemblies(${key})`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`assemblyLines?$filter=documentNo eq '${no}'&$top=100`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function post() {
    setBusy(true);
    setStatus("Post...");
    const r = await BcApi.post(`assemblies(${key})/Microsoft.NAV.post`, "{}");
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: Assembly post edildi (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Assembly Listesi</button>
      <DocHeader
        title={no}
        subtitle={`${BcApi.firstValue(header, "itemNo")} — ${BcApi.firstValue(header, "description")}\nQty: ${Number(header?.quantity ?? 0)} · Kalan: ${Number(header?.remainingQuantity ?? 0)} · ${BcApi.firstValue(header, "locationCode") || "-"}/${BcApi.firstValue(header, "binCode") || "-"} · Durum: ${BcApi.firstValue(header, "status")}`}
      />
      <StatusText status={status} />
      <h3 className="mt16">Components ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card">
            <div className="card-title">
              {String(ln.itemNo)} — {String(ln.description ?? "")}
            </div>
            <div className="card-meta">
              Gerekli: {Number(ln.quantity ?? 0)} · Tüketilen: {Number(ln.consumedQuantity ?? 0)} · Bin: {BcApi.firstValue(ln, "binCode") || "-"}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu assembly'de component yok." />}
      </div>
      <div className="actions">
        <button className="primary big" disabled={busy} onClick={post}>
          ✅ Post Assembly
        </button>
      </div>
    </div>
  );
}
