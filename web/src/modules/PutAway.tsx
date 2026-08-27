import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { friendlyQcStatus, isQcBlocked, extractInspectionNo } from "../lib/qcErrorParser";
import { navigateTo } from "../main";
import { DocHeader, EmptyState, Field, Modal, NumberField, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function PutAway() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get("putAways?$top=30&$select=no,locationCode,assignedUserId,status");
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: PutAway listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Açık put-away yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} put-away (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <PutAwayDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
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
        {rows.length === 0 && !loading && <EmptyState message="Açık put-away yok." />}
      </div>
    </div>
  );
}

function PutAwayDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [qcBlock, setQcBlock] = useState<{ inspectionNo: string | null; raw: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [binLine, setBinLine] = useState<Row | null>(null);

  function handleError(body: string, httpCode: number) {
    const msg = BcApi.errorMessage(body);
    if (isQcBlocked(msg)) {
      setQcBlock({ inspectionNo: extractInspectionNo(msg), raw: msg });
    }
    setStatus(friendlyQcStatus(msg, httpCode));
  }

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`putAways('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`putAwayLines?$filter=no eq '${no}'&$top=100`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function register() {
    setBusy(true);
    setStatus("Register…");
    const r = await BcApi.boundAction("putAways", no, "register", "{}");
    setBusy(false);
    if (r.ok) {
      setStatus(`PASS: Put-Away kaydedildi (HTTP ${r.httpCode})`);
      setQcBlock(null);
      reload();
    } else {
      handleError(r.body, r.httpCode);
    }
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Belge Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Lokasyon: ${BcApi.firstValue(header, "locationCode")} · ${BcApi.firstValue(header, "status")}`}
      />
      {qcBlock && (
        <div className="banner-warn">
          🔬 <b>Quality Inspection bekliyor</b>
          {qcBlock.inspectionNo && (
            <> — denetim <code>{qcBlock.inspectionNo}</code></>
          )}
          . Bu put-away'in lot/serial'i şu an blokda; denetim tamamlanmadan register edilemez.
          <br />
          <small>Detay: {qcBlock.raw}</small>
          <div className="mt8">
            <button className="primary small" onClick={() => navigateTo("qms")}>
              🧫 MS Quality Mgmt'i aç
            </button>
          </div>
        </div>
      )}
      <StatusText status={status} />
      <h3 style={{ marginTop: 16 }}>Satırlar ({lines.length}) — bin atamak için tıklayın</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card clickable" onClick={() => setBinLine(ln)}>
            <div className="card-title">{String(ln.itemNo)} · LP: {BcApi.firstValue(ln, "lpNo") || "-"}</div>
            <div className="card-meta">
              Bin: {BcApi.firstValue(ln, "binCode") || "-"} · İşlenecek: {Number(ln.qtyToHandle ?? 0)}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu belgede satır yok." />}
      </div>
      <div className="actions">
        <button className="primary big" onClick={register} disabled={busy}>
          ✅ Register Put-Away
        </button>
      </div>
      {binLine && (
        <PutAwayBinModal
          line={binLine}
          locationCode={String(header?.locationCode ?? "")}
          onClose={() => setBinLine(null)}
          onSubmit={async (bin, qty) => {
            setBinLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const actType = BcApi.firstValue(binLine, "activityType") || "Put-away";
            const r = await BcApi.patch(
              `putAwayLines(activityType='${actType}',no='${no}',lineNo=${binLine.lineNo})`,
              JSON.stringify({ binCode: bin, qtyToHandle: qty }),
            );
            setBusy(false);
            if (r.ok) {
              setStatus(`PASS: Satır güncellendi → ${bin} (HTTP ${r.httpCode})`);
              setQcBlock(null);
              reload();
            } else {
              handleError(r.body, r.httpCode);
            }
          }}
        />
      )}
    </div>
  );
}

function PutAwayBinModal({
  line,
  locationCode,
  onClose,
  onSubmit,
}: {
  line: Row;
  locationCode: string;
  onClose: () => void;
  onSubmit: (bin: string, qty: number) => void;
}) {
  const [bin, setBin] = useState(String(line.binCode ?? ""));
  const [qty, setQty] = useState(String(Number(line.qtyToHandle ?? 1)));
  const [hint, setHint] = useState("");
  return (
    <Modal
      title="Hedef Bin"
      meta={`Item: ${line.itemNo} · Qty: ${line.qtyToHandle ?? 0}`}
      onClose={onClose}
    >
      <Field label="Bin Code" value={bin} onChange={setBin} placeholder="S-1-01" />
      <div style={{ marginTop: 6 }}>
        <button
          className="outline small"
          onClick={async () => {
            setHint("Bin öneriliyor…");
            const r = await BcApi.post(
              `putAways('${line.no}')/Microsoft.NAV.suggestBin`,
              JSON.stringify({
                itemNo: line.itemNo,
                qty: Number(qty) || 0,
                locationCode,
              }),
            );
            if (r.ok) {
              const suggested = BcApi.scalarValue(r.body);
              if (suggested) {
                setBin(suggested);
                setHint(`Önerilen bin: ${suggested}`);
              } else setHint("Öneri boş döndü.");
            } else setHint(`Öneri alınamadı (HTTP ${r.httpCode})`);
          }}
        >
          🎯 Bin Öner
        </button>
        {hint && <span style={{ marginLeft: 8, color: "var(--text-muted)", fontSize: 12 }}>{hint}</span>}
      </div>
      <div style={{ marginTop: 10 }}>
        <NumberField label="Miktar" value={qty} onChange={setQty} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          disabled={bin.trim().length === 0}
          onClick={() => onSubmit(bin.trim(), Number(qty) || 0)}
        >
          Onayla
        </button>
      </div>
    </Modal>
  );
}
