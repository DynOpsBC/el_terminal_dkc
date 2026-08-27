import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { getDefaultPrinter } from "./Printers";
import {
  Checkbox,
  DocHeader,
  EmptyState,
  Modal,
  NumberField,
  Pill,
  StatusText,
  Tabs,
} from "../ui/primitives";

type Row = Record<string, any>;
type TabKey = "whse" | "so";

export function Shipping() {
  const [tab, setTab] = useState<TabKey>("whse");
  return (
    <div>
      <Tabs
        tabs={[
          { key: "whse", label: "📋 Whse Shipment" },
          { key: "so", label: "🛒 Sales Order" },
        ]}
        active={tab}
        onChange={(k) => setTab(k as TabKey)}
      />
      <div style={{ marginTop: 16 }}>
        {tab === "whse" ? <WhseShipmentTab /> : <SalesOrderTab />}
      </div>
    </div>
  );
}

// ============================================================
// Tab 1 — Warehouse Shipment
// ============================================================

function WhseShipmentTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "shipments?$top=30&$select=no,locationCode,assignedUserId,status,shipmentDate,sourceNo,shipTo,lineCount",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Sevkiyat listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Released Whse Shipment yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} belge (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <ShipDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
  }
  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
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
              Sevk: {BcApi.firstValue(d, "shipTo") || "-"} · Kaynak: {BcApi.firstValue(d, "sourceNo") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Released Whse Shipment yok. SO'dan direkt sevkiyat için sağdaki sekmeyi kullanın." />
        )}
      </div>
    </div>
  );
}

function ShipDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [printSlip, setPrintSlip] = useState(true);
  const [invoice, setInvoice] = useState(false);
  const [qtyLine, setQtyLine] = useState<Row | null>(null);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`shipments('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`shipmentLines?$filter=no eq '${no}'&$top=100`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Belge Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Sevk: ${BcApi.firstValue(header, "shipTo") || "-"} · ${BcApi.firstValue(header, "status")}`}
      />
      <StatusText status={status} />
      <h3 style={{ marginTop: 16 }}>Satırlar ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card clickable" onClick={() => setQtyLine(ln)}>
            <div className="card-title">{String(ln.itemNo)} — {String(ln.description ?? "")}</div>
            <div className="card-meta">
              Sevk edilecek: {Number(ln.qtyToShip ?? 0)} / {Number(ln.qtyOutstanding ?? 0)} · LP: {BcApi.firstValue(ln, "licensePlateNo") || "-"}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu belgede satır yok." />}
      </div>
      <div style={{ marginTop: 12, display: "flex", gap: 18 }}>
        <Checkbox label="Packing slip yazdır" value={printSlip} onChange={setPrintSlip} />
        <Checkbox label="Faturalandır" value={invoice} onChange={setInvoice} />
      </div>
      <div className="actions">
        <button
          className="primary big"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            setStatus("Post…");
            const r = await BcApi.boundAction(
              "shipments", no, "postToPrinter",
              JSON.stringify({ print: printSlip, invoice, printerId: getDefaultPrinter("document") }),
            );
            setBusy(false);
            setStatus(
              r.ok
                ? `PASS: Sevkiyat kaydedildi (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) reload();
          }}
        >
          ✅ Post Shipment
        </button>
      </div>
      {qtyLine && (
        <QtyOnlyModal
          line={qtyLine}
          initialQty={Number(qtyLine.qtyOutstanding ?? 1)}
          onClose={() => setQtyLine(null)}
          onSubmit={async (qty) => {
            setQtyLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const r = await BcApi.patch(
              `shipmentLines(no='${no}',lineNo=${qtyLine.lineNo})`,
              JSON.stringify({ qtyToShip: qty }),
            );
            setBusy(false);
            setStatus(
              r.ok
                ? `PASS: Satır güncellendi qty=${qty} (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) reload();
          }}
        />
      )}
    </div>
  );
}

// ============================================================
// Tab 2 — Sales Order direct ship
// ============================================================

function SalesOrderTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [releasedOnly, setReleasedOnly] = useState(true);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const filter = releasedOnly ? "&$filter=status eq 'Released'" : "";
    const r = await BcApi.get(
      `salesSources?$top=30${filter}&$select=no,customerNo,customerName,shipToName,locationCode,shipmentDate,status,lineCount,outstandingQty,percentComplete,requiresWhseShipment,directShipAllowed`,
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: SO listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: ${releasedOnly ? "Released" : "Açık"} SO yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} satış siparişi (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, [releasedOnly]);

  if (selected) {
    return <ShipSalesOrder no={selected} onBack={() => { setSelected(null); load(); }} />;
  }

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
        <button
          className={`chip ${releasedOnly ? "active" : ""}`}
          onClick={() => setReleasedOnly(!releasedOnly)}
        >
          {releasedOnly ? "Sadece Released" : "Tüm Durumlar"}
        </button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => (
          <div key={String(d.no)} className="card clickable" onClick={() => setSelected(String(d.no))}>
            <div className="row-between">
              <div className="card-title">{String(d.no)}</div>
              <div className="pill-row">
                {d.requiresWhseShipment && <Pill text="⚠ Whse Shipment zorunlu" tone="warn" />}
                <Pill text={String(d.status ?? "")} tone={String(d.status) === "Released" ? "ok" : "neutral"} />
              </div>
            </div>
            <div className="card-meta">
              Müşteri: {BcApi.firstValue(d, "customerName")} ({BcApi.firstValue(d, "customerNo")})
              <br />
              Lokasyon: {BcApi.firstValue(d, "locationCode") || "-"} · Satır: {Number(d.lineCount ?? 0)} · Kalan: {Number(d.outstandingQty ?? 0)}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Uygun satış siparişi yok." />
        )}
      </div>
    </div>
  );
}

function ShipSalesOrder({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [invoiceToo, setInvoiceToo] = useState(false);
  const [qtyLine, setQtyLine] = useState<Row | null>(null);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`salesSources('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(
      `salesSourceLines?$filter=no eq '${no}' and type eq 'Item'&$top=200&$orderby=lineNo`,
    );
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function postShip() {
    setBusy(true);
    setStatus("Post-Ship…");
    const r = await BcApi.boundAction(
      "salesSources",
      no,
      "ship",
      JSON.stringify({ invoice: invoiceToo }),
    );
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: SO sevkiyat kaydedildi (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  const directAllowed = header?.directShipAllowed !== false;
  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ SO Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Müşteri: ${BcApi.firstValue(header, "customerName")} (${BcApi.firstValue(header, "customerNo")})\nLokasyon: ${BcApi.firstValue(header, "locationCode") || "-"} · Durum: ${BcApi.firstValue(header, "status")}`}
        percent={header ? Number(header.percentComplete ?? 0) : 0}
      />
      {header && !directAllowed && (
        <div className="banner-warn">
          ⚠ Bu lokasyon (<b>{BcApi.firstValue(header, "locationCode")}</b>) Warehouse Shipment zorunlu kılıyor.
          Direkt Post Ship yapılamaz. Soldaki “📋 Whse Shipment” sekmesinden ilgili belgeyi açıp sevkiyatı tamamlayın.
        </div>
      )}
      <StatusText status={status} />
      <h3 className="mt16">Satırlar ({lines.length}) — qty düzenlemek için tıklayın</h3>
      <div className="list">
        {lines.map((ln) => (
          <div
            key={String(ln.lineNo)}
            className={`card ${directAllowed ? "clickable" : "disabled"}`}
            onClick={() => directAllowed && setQtyLine(ln)}
          >
            <div className="card-title">{String(ln.itemNo)} — {String(ln.description ?? "")}</div>
            <div className="card-meta">
              Kalan: {Number(ln.outstandingQuantity ?? 0)} · Sevk: {Number(ln.qtyToShip ?? 0)} · Sevk edilen: {Number(ln.qtyShipped ?? 0)}
              <br />
              Bin: {BcApi.firstValue(ln, "binCode") || "-"} · UoM: {BcApi.firstValue(ln, "unitOfMeasureCode")}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && (
          <EmptyState message="Bu SO'da satır yok (veya tümü tamamlandı)." />
        )}
      </div>
      <div className="mt12">
        <Checkbox label="Aynı zamanda faturalandır" value={invoiceToo} onChange={setInvoiceToo} />
      </div>
      <div className="actions">
        <button className="primary big" onClick={postShip} disabled={busy || !directAllowed}>
          {invoiceToo ? "✅ Post Ship & Invoice" : "✅ Post Ship"}
        </button>
      </div>
      {qtyLine && (
        <QtyOnlyModal
          line={qtyLine}
          initialQty={Number(qtyLine.qtyToShip) || Number(qtyLine.outstandingQuantity) || 1}
          onClose={() => setQtyLine(null)}
          onSubmit={async (qty) => {
            setQtyLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const r = await BcApi.patch(
              `salesSourceLines(documentType='Order',no='${no}',lineNo=${qtyLine.lineNo})`,
              JSON.stringify({ qtyToShip: qty }),
            );
            setBusy(false);
            setStatus(
              r.ok
                ? `PASS: SO satırı qty=${qty} (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) reload();
          }}
        />
      )}
    </div>
  );
}

function QtyOnlyModal({
  line,
  initialQty,
  onClose,
  onSubmit,
}: {
  line: Row;
  initialQty: number;
  onClose: () => void;
  onSubmit: (qty: number) => void;
}) {
  const [qty, setQty] = useState(String(initialQty || 1));
  return (
    <Modal
      title="Miktar"
      meta={`Item: ${line.itemNo} · ${line.description ?? ""} · UoM: ${line.unitOfMeasureCode ?? ""}`}
      onClose={onClose}
    >
      <NumberField label="Miktar" value={qty} onChange={setQty} />
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button className="primary" onClick={() => onSubmit(Number(qty) || 0)}>Onayla</button>
      </div>
    </Modal>
  );
}
