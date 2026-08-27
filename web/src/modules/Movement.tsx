import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { DocHeader, EmptyState, Field, NumberField, Pill, StatusText, Tabs } from "../ui/primitives";

type Row = Record<string, any>;
type TabKey = "adhoc" | "directed";

export function Movement({ initialTab = "adhoc" }: { initialTab?: TabKey }) {
  const [tab, setTab] = useState<TabKey>(initialTab);
  return (
    <div>
      <Tabs
        tabs={[
          { key: "adhoc", label: "↔️ Ad-Hoc Hareket" },
          { key: "directed", label: "🎯 Yönlendirilmiş" },
        ]}
        active={tab}
        onChange={(k) => setTab(k as TabKey)}
      />
      <div className="mt16">
        {tab === "adhoc" ? <AdHocTab /> : <DirectedTab />}
      </div>
    </div>
  );
}

// ============================================================
// Tab 1 — Ad-Hoc Bin-to-Bin Movement (single POST, no document)
// ============================================================

function AdHocTab() {
  const [fromBin, setFromBin] = useState("");
  const [toBin, setToBin] = useState("");
  const [itemOrLp, setItemOrLp] = useState("");
  const [qty, setQty] = useState("1");
  const [lot, setLot] = useState("");
  const [serial, setSerial] = useState("");
  const [isLp, setIsLp] = useState(false);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    setStatus("Hareket gönderiliyor...");
    const body: Record<string, unknown> = {
      fromBin: fromBin.trim(),
      toBin: toBin.trim(),
      quantity: Number(qty) || 0,
    };
    if (isLp) {
      body.lpNo = itemOrLp.trim();
    } else {
      body.itemNo = itemOrLp.trim();
    }
    if (lot.trim()) body.lotNo = lot.trim();
    if (serial.trim()) body.serialNo = serial.trim();

    const r = await BcApi.post("movements/Microsoft.NAV.adhoc", JSON.stringify(body));
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: Hareket kaydedildi — ${fromBin} → ${toBin} (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) {
      // Reset for next entry
      setItemOrLp("");
      setQty("1");
      setLot("");
      setSerial("");
    }
  }

  const valid =
    fromBin.trim().length > 0 &&
    toBin.trim().length > 0 &&
    itemOrLp.trim().length > 0 &&
    (Number(qty) || 0) > 0;

  return (
    <div className="adhoc-form">
      <h3 className="mt0">Ad-Hoc Bin-to-Bin Hareket</h3>
      <p className="card-meta mt0">Item veya LP'yi bir bin'den başka bin'e taşı (belgesiz). BC `movements/Microsoft.NAV.adhoc` POST.</p>

      <div className="row mt16">
        <Field label="Kaynak Bin" value={fromBin} onChange={setFromBin} placeholder="RECEIVE-1" />
        <Field label="Hedef Bin" value={toBin} onChange={setToBin} placeholder="PICK-01" />
      </div>

      <div className="mt12">
        <label className="field" htmlFor="adhoc-kind">Item mi LP mi?</label>
        <select
          id="adhoc-kind"
          title="Hareket tipi (item vs LP)"
          value={isLp ? "lp" : "item"}
          onChange={(e) => setIsLp(e.target.value === "lp")}
        >
          <option value="item">Item (item no)</option>
          <option value="lp">License Plate (LP no)</option>
        </select>
      </div>

      <div className="mt12">
        <Field
          label={isLp ? "LP No" : "Item No"}
          value={itemOrLp}
          onChange={setItemOrLp}
          placeholder={isLp ? "LP000123" : "1896-S"}
        />
      </div>

      <div className="row mt12">
        <NumberField label="Miktar" value={qty} onChange={setQty} />
        <Field label="Lot No (ops.)" value={lot} onChange={setLot} />
      </div>

      <div className="mt12">
        <Field label="Serial No (ops.)" value={serial} onChange={setSerial} />
      </div>

      <StatusText status={status} />

      <div className="actions">
        <button className="primary big full" disabled={busy || !valid} onClick={submit}>
          {busy ? "Gönderiliyor..." : "✅ Hareketi Onayla"}
        </button>
      </div>
    </div>
  );
}

// ============================================================
// Tab 2 — Directed Movement (list + register)
// ============================================================

function DirectedTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get("movements?$top=30&$select=no,locationCode,assignedUserId,status");
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Movement listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Açık movement yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} movement (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <DirectedMovementDoc no={selected} onBack={() => { setSelected(null); load(); }} />;
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
              <div className="card-title">{String(d.no)}</div>
              <Pill text={String(d.status ?? "")} tone="neutral" />
            </div>
            <div className="card-meta">
              Lokasyon: {BcApi.firstValue(d, "locationCode")} · Atanan: {BcApi.firstValue(d, "assignedUserId") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <EmptyState message="Açık yönlendirilmiş movement yok." />}
      </div>
    </div>
  );
}

function DirectedMovementDoc({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`movements('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`movementLines?$filter=no eq '${no}'&$top=200`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function register() {
    setBusy(true);
    setStatus("Register...");
    const r = await BcApi.boundAction("movements", no, "register", "{}");
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: Movement register edildi (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Movement Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Lokasyon: ${BcApi.firstValue(header, "locationCode")} · Atanan: ${BcApi.firstValue(header, "assignedUserId") || "-"} · Durum: ${BcApi.firstValue(header, "status")}`}
      />
      <StatusText status={status} />
      <h3 className="mt16">Satırlar ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card">
            <div className="card-title">
              {String(ln.itemNo)} · {BcApi.firstValue(ln, "actionType")}
            </div>
            <div className="card-meta">
              Kaynak: {BcApi.firstValue(ln, "fromBinCode") || BcApi.firstValue(ln, "binCode") || "-"} → Hedef: {BcApi.firstValue(ln, "toBinCode") || "-"} · Qty: {Number(ln.qty ?? ln.qtyToHandle ?? 0)}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu movement'ta satır yok." />}
      </div>
      <div className="actions">
        <button className="primary big" disabled={busy} onClick={register}>
          ✅ Register Movement
        </button>
      </div>
    </div>
  );
}
