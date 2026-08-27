import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { getDefaultPrinter } from "./Printers";
import {
  Checkbox,
  DocHeader,
  EmptyState,
  Field,
  Modal,
  NumberField,
  Pill,
  StatusText,
  Tabs,
} from "../ui/primitives";

type Row = Record<string, any>;
type TabKey = "whse" | "po";

export function Receiving() {
  const [tab, setTab] = useState<TabKey>("whse");
  return (
    <div>
      <Tabs
        tabs={[
          { key: "whse", label: "📋 Whse Receipt" },
          { key: "po", label: "🛒 Purchase Order" },
        ]}
        active={tab}
        onChange={(k) => setTab(k as TabKey)}
      />
      <div style={{ marginTop: 16 }}>
        {tab === "whse" ? <WhseReceiptTab /> : <PurchaseOrderTab />}
      </div>
    </div>
  );
}

// ============================================================
// Tab 1 — Warehouse Receipt
// ============================================================

function WhseReceiptTab() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.getWithStandardFallback(
      "receipts?$top=30&$select=no,locationCode,sourceNo,vendorSourceName,dueDate,percentComplete",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Liste alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: Açık Whse Receipt yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} belge (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => {
    load();
  }, []);

  if (selected) {
    return <ReceiveDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
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
          <div
            key={String(d.no)}
            className="card clickable"
            onClick={() => setSelected(String(d.no))}
          >
            <div className="row-between">
              <div className="card-title">{String(d.no)}</div>
              <Pill text={String(d.percentComplete ?? 0) + "%"} tone="neutral" />
            </div>
            <div className="card-meta">
              Lokasyon: {BcApi.firstValue(d, "locationCode") || "-"} · Kaynak: {BcApi.firstValue(d, "sourceNo") || "-"}
              {BcApi.firstValue(d, "vendorSourceName") && ` · ${BcApi.firstValue(d, "vendorSourceName")}`}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Açık Whse Receipt belgesi yok. PO'dan direkt mal kabul için sağdaki sekmeyi kullanın." />
        )}
      </div>
    </div>
  );
}

function ReceiveDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [activeLp, setActiveLp] = useState<string | null>(null);
  const [qtyLine, setQtyLine] = useState<Row | null>(null);
  const [printReceipt, setPrintReceipt] = useState(false);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`receipts('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`receiptLines?$filter=no eq '${no}'&$top=100`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function action(name: string, body: string, okMsg: string, onOk?: (body: string) => void) {
    setBusy(true);
    setStatus(`${name}...`);
    const r = await BcApi.boundAction("receipts", no, name, body);
    setBusy(false);
    if (r.ok) {
      setStatus(`PASS: ${okMsg} (HTTP ${r.httpCode})`);
      onOk?.(r.body);
      reload();
    } else {
      setStatus(`HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`);
    }
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Belge Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Lokasyon: ${BcApi.firstValue(header, "locationCode") || "-"} · Kaynak: ${BcApi.firstValue(header, "sourceNo") || "-"}${activeLp ? `\nAktif LP: ${activeLp}` : ""}`}
        percent={header ? Number(header.percentComplete ?? 0) : 0}
      />
      <StatusText status={status} />

      <h3 style={{ marginTop: 16 }}>Satırlar ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card clickable" onClick={() => setQtyLine(ln)}>
            <div className="card-title">{String(ln.itemNo)} — {String(ln.description ?? "")}</div>
            <div className="card-meta">
              Kalan: {Number(ln.qtyToReceive ?? 0)} · Alınan: {Number(ln.qtyReceived ?? 0)}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu belgede satır yok." />}
      </div>

      <div style={{ marginTop: 12 }}>
        <Checkbox label="Mal kabul belgesi yazdır" value={printReceipt} onChange={setPrintReceipt} />
      </div>
      <div className="actions">
        {!activeLp ? (
          <button
            className="outline"
            disabled={busy}
            onClick={() =>
              action("startLP", JSON.stringify({ lpTemplateCode: "CARTON-S" }), "LP başlatıldı", (body) =>
                setActiveLp(BcApi.scalarValue(body)),
              )
            }
          >
            🏗️ Start LP
          </button>
        ) : (
          <button
            className="outline"
            disabled={busy}
            onClick={() =>
              action("stopLPToPrinter", JSON.stringify({ lpNo: activeLp, printLabel: true, printerId: getDefaultPrinter() }), "LP kapatıldı", () =>
                setActiveLp(null),
              )
            }
          >
            🔚 Stop LP ({activeLp})
          </button>
        )}
        <button
          className="primary big"
          disabled={busy}
          onClick={() => action("postToPrinter", JSON.stringify({ print: printReceipt, invoice: false, printerId: getDefaultPrinter("document") }), "Mal kabul kaydedildi")}
        >
          ✅ Post Receipt
        </button>
      </div>

      {qtyLine && (
        <LineQtyModal
          line={qtyLine}
          field="qtyToReceive"
          initialQty={Number(qtyLine.qtyToReceive ?? qtyLine.outstandingQuantity ?? 1)}
          onClose={() => setQtyLine(null)}
          onSubmit={async (qty, lot, serial) => {
            setQtyLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const body: Record<string, unknown> = { qtyToReceive: qty };
            if (lot) body.lotNo = lot;
            if (serial) body.serialNo = serial;
            if (activeLp) body.licensePlateNo = activeLp;
            const r = await BcApi.patch(
              `receiptLines(no='${no}',lineNo=${qtyLine.lineNo})`,
              JSON.stringify(body),
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
// Tab 2 — Purchase Order direct receive
// ============================================================

function PurchaseOrderTab() {
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
      `purchaseSources?$top=30${filter}&$select=no,vendorNo,vendorName,locationCode,expectedReceiptDate,status,lineCount,outstandingQty,percentComplete,requiresWhseReceipt,directReceiveAllowed`,
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: PO listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 100)}`
        : arr.length === 0
        ? `EMPTY: ${releasedOnly ? "Released" : "Açık"} PO yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} satınalma siparişi (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, [releasedOnly]);

  if (selected) {
    return <ReceivePurchaseOrder no={selected} onBack={() => { setSelected(null); load(); }} />;
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
              <div style={{ display: "flex", gap: 6 }}>
                {d.requiresWhseReceipt && <Pill text="⚠ Whse Receipt zorunlu" tone="warn" />}
                <Pill text={String(d.status ?? "")} tone={String(d.status) === "Released" ? "ok" : "neutral"} />
              </div>
            </div>
            <div className="card-meta">
              Tedarikçi: {BcApi.firstValue(d, "vendorName")} ({BcApi.firstValue(d, "vendorNo")})
              <br />
              Lokasyon: {BcApi.firstValue(d, "locationCode") || "-"} · Satır: {Number(d.lineCount ?? 0)} · Kalan: {Number(d.outstandingQty ?? 0)}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && (
          <EmptyState message="Uygun satınalma siparişi yok." />
        )}
      </div>
    </div>
  );
}

function ReceivePurchaseOrder({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [invoiceToo, setInvoiceToo] = useState(false);
  const [qtyLine, setQtyLine] = useState<Row | null>(null);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`purchaseSources('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(
      `purchaseSourceLines?$filter=no eq '${no}' and type eq 'Item'&$top=200&$orderby=lineNo`,
    );
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function postReceive() {
    setBusy(true);
    setStatus("Post-Receive…");
    const r = await BcApi.boundAction(
      "purchaseSources",
      no,
      "receive",
      JSON.stringify({ invoice: invoiceToo }),
    );
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: PO mal kabul kaydedildi (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  const directAllowed = header?.directReceiveAllowed !== false;
  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ PO Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Tedarikçi: ${BcApi.firstValue(header, "vendorName")} (${BcApi.firstValue(header, "vendorNo")})\nLokasyon: ${BcApi.firstValue(header, "locationCode") || "-"} · Durum: ${BcApi.firstValue(header, "status")}`}
        percent={header ? Number(header.percentComplete ?? 0) : 0}
      />
      {header && !directAllowed && (
        <div className="banner-warn">
          ⚠ Bu lokasyon (<b>{BcApi.firstValue(header, "locationCode")}</b>) Warehouse Receipt zorunlu kılıyor.
          Direkt Post Receive yapılamaz. Soldaki “📋 Whse Receipt” sekmesinden ilgili belgeyi açıp mal kabulü tamamlayın.
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
              Kalan: {Number(ln.outstandingQuantity ?? 0)} · Alınacak: {Number(ln.qtyToReceive ?? 0)} · Alınan: {Number(ln.qtyReceived ?? 0)}
              <br />
              Bin: {BcApi.firstValue(ln, "binCode") || "-"} · UoM: {BcApi.firstValue(ln, "unitOfMeasureCode")}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && (
          <EmptyState message="Bu PO'da satır yok (veya tümü tamamlandı)." />
        )}
      </div>

      <div className="mt12">
        <Checkbox label="Aynı zamanda faturalandır" value={invoiceToo} onChange={setInvoiceToo} />
      </div>

      <div className="actions">
        <button className="primary big" onClick={postReceive} disabled={busy || !directAllowed}>
          {invoiceToo ? "✅ Post Receive & Invoice" : "✅ Post Receive"}
        </button>
      </div>

      {qtyLine && (
        <LineQtyModal
          line={qtyLine}
          field="qtyToReceive"
          initialQty={Number(qtyLine.qtyToReceive) || Number(qtyLine.outstandingQuantity) || 1}
          onClose={() => setQtyLine(null)}
          onSubmit={async (qty) => {
            setQtyLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const r = await BcApi.patch(
              `purchaseSourceLines(documentType='Order',no='${no}',lineNo=${qtyLine.lineNo})`,
              JSON.stringify({ qtyToReceive: qty }),
            );
            setBusy(false);
            setStatus(
              r.ok
                ? `PASS: PO satırı qty=${qty} (HTTP ${r.httpCode})`
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
// Shared: qty modal
// ============================================================

function LineQtyModal({
  line,
  field,
  initialQty,
  onClose,
  onSubmit,
}: {
  line: Row;
  field: string;
  initialQty: number;
  onClose: () => void;
  onSubmit: (qty: number, lot?: string, serial?: string) => void;
}) {
  const [qty, setQty] = useState(String(initialQty || 1));
  const [lot, setLot] = useState("");
  const [serial, setSerial] = useState("");

  return (
    <Modal
      title={`Miktar — ${field}`}
      meta={`Item: ${line.itemNo} · ${line.description ?? ""} · UoM: ${line.unitOfMeasureCode ?? ""}`}
      onClose={onClose}
    >
      <NumberField label="Miktar" value={qty} onChange={setQty} />
      <div className="row">
        <Field label="Lot No (ops.)" value={lot} onChange={setLot} />
        <Field label="Serial No (ops.)" value={serial} onChange={setSerial} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onSubmit(Number(qty) || 0, lot.trim() || undefined, serial.trim() || undefined)}
        >
          Onayla
        </button>
      </div>
    </Modal>
  );
}
