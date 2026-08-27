import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { getDefaultPrinter } from "./Printers";
import { DocHeader, EmptyState, Field, Modal, NumberField, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function LicensePlate() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  const [showBuild, setShowBuild] = useState(false);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const filter = search.trim() ? `&$filter=contains(no,'${search.trim()}')` : "";
    const r = await BcApi.get(
      `licensePlates?$top=30${filter}&$select=no,templateCode,status,locationCode,binCode,sscc,parentLpNo,assignedDocumentType,assignedDocumentNo`,
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: LP listesi alınamadı (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} LP (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <LpDetail no={selected} onBack={() => { setSelected(null); load(); }} />;
  }

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
        <button className="primary" onClick={() => setShowBuild(true)} disabled={loading}>
          ➕ Yeni LP
        </button>
        <div className="lp-search">
          <input
            type="text"
            placeholder="LP No ara (örn. LP000)"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && load()}
          />
        </div>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => (
          <div key={String(d.no)} className="card clickable" onClick={() => setSelected(String(d.no))}>
            <div className="row-between">
              <div className="card-title">{String(d.no)}</div>
              <Pill text={String(d.status ?? "")} tone={String(d.status) === "Built" ? "ok" : "neutral"} />
            </div>
            <div className="card-meta">
              {BcApi.firstValue(d, "templateCode")} · Lokasyon: {BcApi.firstValue(d, "locationCode")}/{BcApi.firstValue(d, "binCode") || "-"}
              <br />
              SSCC: {BcApi.firstValue(d, "sscc") || "-"} · Parent: {BcApi.firstValue(d, "parentLpNo") || "-"}{BcApi.firstValue(d, "assignedDocumentNo") && ` · Atanan: ${BcApi.firstValue(d, "assignedDocumentType")}/${BcApi.firstValue(d, "assignedDocumentNo")}`}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <EmptyState message="Hiç LP yok. ➕ Yeni LP ile başlayın." />}
      </div>
      {showBuild && (
        <BuildLpModal
          onClose={() => setShowBuild(false)}
          onCreated={(newNo) => {
            setShowBuild(false);
            setSelected(newNo);
          }}
        />
      )}
    </div>
  );
}

function LpDetail({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [showTransfer, setShowTransfer] = useState(false);
  const [showAddLine, setShowAddLine] = useState(false);
  const [showPartial, setShowPartial] = useState(false);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`licensePlates('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`licensePlateLines?$filter=lpNo eq '${no}'&$top=200`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function action(name: string, body: string, okMsg: string) {
    setBusy(true);
    setStatus(`${name}…`);
    const r = await BcApi.boundAction("licensePlates", no, name, body);
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: ${okMsg} (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  const isBuilt = String(header?.status ?? "") === "Built";

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ LP Listesi</button>
      <DocHeader
        title={no}
        subtitle={`${BcApi.firstValue(header, "templateCode")} · ${BcApi.firstValue(header, "status")}\nLokasyon: ${BcApi.firstValue(header, "locationCode")}/${BcApi.firstValue(header, "binCode") || "-"} · SSCC: ${BcApi.firstValue(header, "sscc") || "-"}`}
      />
      <StatusText status={status} />
      <h3 className="mt16">Satırlar ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={`${ln.lpNo}-${ln.lineNo}`} className="card">
            <div className="card-title">
              #{Number(ln.lineNo)} · {String(ln.itemNo)} × {Number(ln.quantity ?? 0)} {BcApi.firstValue(ln, "unitOfMeasure")}
            </div>
            <div className="card-meta">
              Kaynak raf: {BcApi.firstValue(ln, "sourceBinCode") || "-"} · Lot: {BcApi.firstValue(ln, "lotNo") || "-"} · Serial: {BcApi.firstValue(ln, "serialNo") || "-"}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu LP'de satır yok. ➕ Satır ile başlayın." />}
      </div>
      <div className="actions">
        <button className="outline" disabled={busy || isBuilt} onClick={() => setShowAddLine(true)}>
          ➕ Satır
        </button>
        <button
          className="primary"
          disabled={busy || isBuilt}
          onClick={() => action("stopToPrinter", JSON.stringify({ printLabel: true, printerId: getDefaultPrinter() }), "LP kapatıldı + etiket")}
        >
          🔚 Stop
        </button>
        <button className="outline" disabled={busy} onClick={() => action("printLabel", JSON.stringify({ printerId: getDefaultPrinter(), copies: 1 }), "Etiket kuyruğa alındı")}>
          🖨️ Print
        </button>
        <button className="outline" disabled={busy} onClick={() => setShowTransfer(true)}>
          ↔️ Transfer
        </button>
      </div>
      <div className="actions mt8">
        <button className="outline" disabled={busy || lines.length === 0} onClick={() => setShowPartial(true)}>
          ✂️ Partial Use
        </button>
        <button className="outline danger-outline" disabled={busy} onClick={() => {
          if (confirm(`LP ${no} unbuild edilecek. Devam?`)) action("unbuild", "{}", "LP unbuild edildi");
        }}>
          ↩️ Unbuild
        </button>
      </div>
      {showAddLine && (
        <AddLineModal
          onClose={() => setShowAddLine(false)}
          onSubmit={async (itemNo, qty, uom, sourceBin, lot, serial) => {
            setShowAddLine(false);
            await action(
              "addLineFromBin",
              JSON.stringify({
                itemNo,
                unitOfMeasure: uom,
                quantity: qty,
                lotNo: lot ?? "",
                serialNo: serial ?? "",
                sourceBinCode: sourceBin,
                userId: "WEB",
              }),
              `Satır eklendi ve stok ${sourceBin} → ${BcApi.firstValue(header, "binCode")} taşındı (${itemNo} × ${qty})`,
            );
          }}
        />
      )}
      {showTransfer && (
        <TransferModal
          onClose={() => setShowTransfer(false)}
          onSubmit={(target) => {
            setShowTransfer(false);
            action("transfer", JSON.stringify({ targetLpNo: target, linesJson: "" }), `LP içeriği ${target}'a taşındı`);
          }}
        />
      )}
      {showPartial && (
        <PartialUseModal
          lines={lines}
          onClose={() => setShowPartial(false)}
          onSubmit={(mode, qty, lineNo) => {
            setShowPartial(false);
            action(
              "usePartial",
              JSON.stringify({ action: mode, qty, lineNo }),
              `Partial use (${mode}, qty=${qty}, line=${lineNo})`,
            );
          }}
        />
      )}
    </div>
  );
}

// ============================================================
// Modals
// ============================================================

function BuildLpModal({ onClose, onCreated }: { onClose: () => void; onCreated: (no: string) => void }) {
  const [template, setTemplate] = useState("CARTON-S");
  const [location, setLocation] = useState("SILVER");
  const [bin, setBin] = useState("S-1-01");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  async function submit() {
    setBusy(true);
    setErr("");
    const body = JSON.stringify({
      templateCode: template.trim(),
      locationCode: location.trim(),
      binCode: bin.trim(),
    });
    const r = await BcApi.post("licensePlates", body);
    setBusy(false);
    if (r.ok) {
      try {
        const obj = JSON.parse(r.body);
        onCreated(String(obj.no ?? ""));
      } catch {
        onCreated("");
      }
    } else {
      setErr(`HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`);
    }
  }

  return (
    <Modal title="Yeni License Plate" meta="Build edilecek LP için şablon + konum + bin seç" onClose={onClose}>
      <Field label="Template Code" value={template} onChange={setTemplate} placeholder="CARTON-S / PALLET-EUR / TOTE-A" />
      <div className="row mt12">
        <Field label="Location" value={location} onChange={setLocation} placeholder="SILVER" />
        <Field label="Bin" value={bin} onChange={setBin} placeholder="S-1-01" />
      </div>
      {err && <div className="status err mt12">{err}</div>}
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose} disabled={busy}>İptal</button>
        <button className="primary" onClick={submit} disabled={busy || template.trim().length === 0}>
          {busy ? "Oluşturuluyor..." : "Build"}
        </button>
      </div>
    </Modal>
  );
}

function AddLineModal({
  onClose,
  onSubmit,
}: {
  onClose: () => void;
  onSubmit: (itemNo: string, qty: number, uom: string, sourceBin: string, lot?: string, serial?: string) => void;
}) {
  const [itemNo, setItemNo] = useState("");
  const [qty, setQty] = useState("1");
  const [uom, setUom] = useState("PCS");
  const [sourceBin, setSourceBin] = useState("");
  const [lot, setLot] = useState("");
  const [serial, setSerial] = useState("");

  return (
    <Modal title="Satır Ekle" meta="LP'ye yeni item ekle" onClose={onClose}>
      <Field label="Item No" value={itemNo} onChange={setItemNo} placeholder="1896-S" />
      <div className="row mt12">
        <NumberField label="Miktar" value={qty} onChange={setQty} />
        <Field label="UoM" value={uom} onChange={setUom} placeholder="PCS" />
      </div>
      <div className="mt12">
        <Field label="Kaynak Raf" value={sourceBin} onChange={setSourceBin} placeholder="A.B04.13" />
      </div>
      <div className="row mt12">
        <Field label="Lot No (ops.)" value={lot} onChange={setLot} />
        <Field label="Serial No (ops.)" value={serial} onChange={setSerial} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onSubmit(itemNo.trim(), Number(qty) || 0, uom.trim(), sourceBin.trim(), lot.trim() || undefined, serial.trim() || undefined)}
          disabled={itemNo.trim().length === 0 || sourceBin.trim().length === 0 || (Number(qty) || 0) <= 0}
        >
          Onayla
        </button>
      </div>
    </Modal>
  );
}

function TransferModal({ onClose, onSubmit }: { onClose: () => void; onSubmit: (target: string) => void }) {
  const [target, setTarget] = useState("");
  return (
    <Modal title="LP Transfer" meta="Tüm satırları hedef LP'ye taşı" onClose={onClose}>
      <Field label="Hedef LP No" value={target} onChange={setTarget} placeholder="LP000123" />
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button className="primary" onClick={() => onSubmit(target.trim())} disabled={target.trim().length === 0}>
          Transfer Et
        </button>
      </div>
    </Modal>
  );
}

function PartialUseModal({
  lines,
  onClose,
  onSubmit,
}: {
  lines: Row[];
  onClose: () => void;
  onSubmit: (mode: "CreateNewLP" | "Unbuild", qty: number, lineNo: number) => void;
}) {
  const firstLine = lines[0];
  const [mode, setMode] = useState<"CreateNewLP" | "Unbuild">("CreateNewLP");
  const [qty, setQty] = useState(String(Number(firstLine?.quantity ?? 1)));
  const [lineNo, setLineNo] = useState(String(Number(firstLine?.lineNo ?? 10000)));

  return (
    <Modal
      title="Partial Use"
      meta="LP satırını kısmi olarak kullan: yeni LP yarat veya unbuild et"
      onClose={onClose}
    >
      <label className="field" htmlFor="partial-mode">Mod</label>
      <select
        id="partial-mode"
        title="Partial use modu"
        value={mode}
        onChange={(e) => setMode(e.target.value as "CreateNewLP" | "Unbuild")}
      >
        <option value="CreateNewLP">CreateNewLP — kalanı yeni LP'ye al</option>
        <option value="Unbuild">Unbuild — fazlasını loose dök</option>
      </select>
      <div className="row mt12">
        <NumberField label="Miktar (kullanılacak)" value={qty} onChange={setQty} />
        <NumberField label="Satır No" value={lineNo} onChange={setLineNo} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onSubmit(mode, Number(qty) || 0, Number(lineNo) || 0)}
          disabled={(Number(qty) || 0) <= 0 || (Number(lineNo) || 0) <= 0}
        >
          Uygula
        </button>
      </div>
    </Modal>
  );
}
