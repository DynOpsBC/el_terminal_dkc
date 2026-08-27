import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { EmptyState, Field, Modal, NumberField, Pill, StatusText, Tabs } from "../ui/primitives";

type Row = Record<string, any>;
type TabKey = "consume" | "output";

export function Production() {
  const [tab, setTab] = useState<TabKey>("consume");
  return (
    <div>
      <Tabs
        tabs={[
          { key: "consume", label: "📥 Sarfiyat (Consume)" },
          { key: "output", label: "📤 Output (Report)" },
        ]}
        active={tab}
        onChange={(k) => setTab(k as TabKey)}
      />
      <div className="mt16">
        {tab === "consume" ? <ConsumeTab /> : <OutputTab />}
      </div>
    </div>
  );
}

// ============================================================
// Tab 1 — Production Consumption (component → consume)
// ============================================================

function ConsumeTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<Row | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "productionConsumption?$top=50&$select=prodOrderNo,prodOrderLineNo,componentLineNo,itemNo,description,quantity,remainingQuantity,binCode,locationCode,status",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Consumption listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: Açık prod order component yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} component (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>{loading ? "..." : "🔄 Yenile"}</button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => (
          <div
            key={`${d.prodOrderNo}-${d.prodOrderLineNo}-${d.componentLineNo}`}
            className="card clickable"
            onClick={() => setSelected(d)}
          >
            <div className="row-between">
              <div className="card-title">
                {String(d.prodOrderNo)} · {String(d.itemNo)}
              </div>
              <Pill text={String(d.status ?? "")} tone="neutral" />
            </div>
            <div className="card-meta">
              {String(d.description ?? "")}
              <br />
              Gerekli: {Number(d.quantity ?? 0)} · Kalan: {Number(d.remainingQuantity ?? 0)} · Bin: {BcApi.firstValue(d, "binCode") || "-"} @ {BcApi.firstValue(d, "locationCode") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Açık production order component yok." />
        )}
      </div>
      {selected && (
        <ConsumeModal
          line={selected}
          onClose={() => setSelected(null)}
          onSubmit={async (payload) => {
            setSelected(null);
            setLoading(true);
            setStatus("Sarfiyat kaydediliyor...");
            const key =
              `status='${selected.status || "Released"}',` +
              `prodOrderNo='${selected.prodOrderNo}',` +
              `prodOrderLineNo=${Number(selected.prodOrderLineNo)},` +
              `componentLineNo=${Number(selected.componentLineNo)}`;
            const r = await BcApi.post(
              `productionConsumption(${key})/Microsoft.NAV.consume`,
              JSON.stringify(payload),
            );
            setLoading(false);
            setStatus(
              r.ok
                ? `PASS: Sarfiyat kaydedildi (qty=${payload.qty}) (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) load();
          }}
        />
      )}
    </div>
  );
}

function ConsumeModal({
  line,
  onClose,
  onSubmit,
}: {
  line: Row;
  onClose: () => void;
  onSubmit: (p: { itemNo: string; qty: number; lpNo?: string; lotNo?: string; serialNo?: string; binCode?: string }) => void;
}) {
  const [itemNo] = useState(String(line.itemNo ?? ""));
  const [qty, setQty] = useState(String(Number(line.remainingQuantity ?? line.quantity ?? 0)));
  const [lpNo, setLpNo] = useState("");
  const [lot, setLot] = useState("");
  const [serial, setSerial] = useState("");
  const [bin, setBin] = useState(String(line.binCode ?? ""));

  return (
    <Modal
      title="Sarfiyat Kaydet"
      meta={`Prod: ${line.prodOrderNo} · Item: ${itemNo} · ${line.description ?? ""}`}
      onClose={onClose}
    >
      <NumberField label="Sarf miktarı" value={qty} onChange={setQty} />
      <div className="row mt12">
        <Field label="LP No (ops.)" value={lpNo} onChange={setLpNo} placeholder="LP000123" />
        <Field label="Bin Code" value={bin} onChange={setBin} />
      </div>
      <div className="row mt12">
        <Field label="Lot No (ops.)" value={lot} onChange={setLot} />
        <Field label="Serial No (ops.)" value={serial} onChange={setSerial} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() =>
            onSubmit({
              itemNo,
              qty: Number(qty) || 0,
              lpNo: lpNo.trim() || undefined,
              lotNo: lot.trim() || undefined,
              serialNo: serial.trim() || undefined,
              binCode: bin.trim() || undefined,
            })
          }
          disabled={(Number(qty) || 0) <= 0}
        >
          Consume
        </button>
      </div>
    </Modal>
  );
}

// ============================================================
// Tab 2 — Production Output (routing line → report)
// ============================================================

function OutputTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<Row | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "productionOutput?$top=50&$select=prodOrderNo,routingLineNo,routingNo,operationNo,workCenterNo,description,runTime,status",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Output listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: Açık routing line yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} routing line (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>{loading ? "..." : "🔄 Yenile"}</button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => (
          <div
            key={`${d.prodOrderNo}-${d.routingLineNo}`}
            className="card clickable"
            onClick={() => setSelected(d)}
          >
            <div className="row-between">
              <div className="card-title">
                {String(d.prodOrderNo)} · Op {String(d.operationNo)}
              </div>
              <Pill text={String(d.status ?? "")} tone="neutral" />
            </div>
            <div className="card-meta">
              {String(d.description ?? "")} · WC: {BcApi.firstValue(d, "workCenterNo") || "-"} · Routing: {BcApi.firstValue(d, "routingNo") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Açık routing line yok." />
        )}
      </div>
      {selected && (
        <OutputModal
          line={selected}
          onClose={() => setSelected(null)}
          onSubmit={async (payload) => {
            setSelected(null);
            setLoading(true);
            setStatus("Output kaydediliyor...");
            const key =
              `status='${selected.status || "Released"}',` +
              `prodOrderNo='${selected.prodOrderNo}',` +
              `routingLineNo=${Number(selected.routingLineNo)},` +
              `routingNo='${selected.routingNo}',` +
              `operationNo='${selected.operationNo}'`;
            const r = await BcApi.post(
              `productionOutput(${key})/Microsoft.NAV.report`,
              JSON.stringify(payload),
            );
            setLoading(false);
            if (r.ok) {
              const lp = BcApi.scalarValue(r.body);
              setStatus(`PASS: Output kaydedildi${lp ? ` → LP ${lp}` : ""} (HTTP ${r.httpCode})`);
              load();
            } else {
              setStatus(`HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`);
            }
          }}
        />
      )}
    </div>
  );
}

function OutputModal({
  line,
  onClose,
  onSubmit,
}: {
  line: Row;
  onClose: () => void;
  onSubmit: (p: { outputQty: number; scrapQty: number; runtime: number; newLpTemplate?: string; binCode?: string }) => void;
}) {
  const [outputQty, setOutputQty] = useState("1");
  const [scrapQty, setScrapQty] = useState("0");
  const [runtime, setRuntime] = useState(String(Number(line.runTime ?? 60)));
  const [newLpTemplate, setNewLpTemplate] = useState("");
  const [bin, setBin] = useState("");

  return (
    <Modal
      title="Output Raporu"
      meta={`Prod: ${line.prodOrderNo} · Op ${line.operationNo} · ${line.description ?? ""}`}
      onClose={onClose}
    >
      <div className="row">
        <NumberField label="Output qty" value={outputQty} onChange={setOutputQty} />
        <NumberField label="Scrap qty" value={scrapQty} onChange={setScrapQty} />
      </div>
      <div className="mt12">
        <NumberField label="Runtime (dakika)" value={runtime} onChange={setRuntime} />
      </div>
      <div className="row mt12">
        <Field label="Yeni LP Template (ops.)" value={newLpTemplate} onChange={setNewLpTemplate} placeholder="CARTON-M" />
        <Field label="Bin Code (ops.)" value={bin} onChange={setBin} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() =>
            onSubmit({
              outputQty: Number(outputQty) || 0,
              scrapQty: Number(scrapQty) || 0,
              runtime: Number(runtime) || 0,
              newLpTemplate: newLpTemplate.trim() || undefined,
              binCode: bin.trim() || undefined,
            })
          }
          disabled={(Number(outputQty) || 0) <= 0}
        >
          Report Output
        </button>
      </div>
    </Modal>
  );
}
