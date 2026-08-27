import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { DocHeader, EmptyState, Modal, NumberField, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function Count() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(
      "countSheets?$top=30&$select=no,locationCode,status,mode,createdDateTime",
    );
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Count listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Sayım yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} sayfa (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <CountDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
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
              <Pill text={String(d.status ?? "") + " · " + String(d.mode ?? "")} tone="neutral" />
            </div>
            <div className="card-meta">
              Lokasyon: {BcApi.firstValue(d, "locationCode")} · Oluşturma: {BcApi.firstValue(d, "createdDateTime") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <EmptyState message="Açık sayım yok." />}
      </div>
    </div>
  );
}

function CountDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [countLine, setCountLine] = useState<Row | null>(null);

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`countSheets('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`countSheetLines?$filter=sheetNo eq '${no}'&$top=200`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function action(name: string, okMsg: string) {
    setBusy(true);
    setStatus(`${name}…`);
    const r = await BcApi.boundAction("countSheets", no, name, "{}");
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: ${okMsg} (HTTP ${r.httpCode})`
        : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  const mode = String(header?.mode ?? "");
  const blind = mode === "Blind";
  const sheetStatus = String(header?.status ?? "");

  function fmt(n: number) {
    return Number(n).toLocaleString("tr-TR");
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Sayfa Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Lokasyon: ${BcApi.firstValue(header, "locationCode")} · Mode: ${mode} · ${sheetStatus}`}
      />
      <StatusText status={status} />
      <h3 className="mt16">Satırlar ({lines.length}) — sayım girmek için tıklayın</h3>
      <div className="list">
        {lines.map((ln) => {
          const c1 = Number(ln.countedQty1 ?? 0);
          const c2 = Number(ln.countedQty2 ?? 0);
          const c3 = Number(ln.countedQty3 ?? 0);
          const counts = [c1, c2, c3].filter((q) => q !== 0).map(fmt).join(" / ") || "—";
          const sys = Number(ln.systemQty ?? 0);
          const variance = Number(ln.variance ?? 0);
          const recount = Boolean(ln.recountRequired);
          const lot = String(ln.lotNo ?? "");
          const serial = String(ln.serialNo ?? "");
          const lpNo = String(ln.lpNo ?? "");
          const tracking = [lot ? `Lot: ${lot}` : "", serial ? `Seri: ${serial}` : ""].filter(Boolean).join(" · ");
          return (
            <div key={String(ln.lineNo)} className="card clickable" onClick={() => setCountLine(ln)}>
              <div className="row-between">
                <div className="card-title">{String(ln.itemNo)} · Bin: {BcApi.firstValue(ln, "binCode") || "-"}</div>
                {recount && <Pill text="⟳ recount" tone="warn" />}
              </div>
              <div className="card-meta">
                {lpNo && <>LP: {lpNo} · </>}
                {tracking && <>{tracking} · </>}
                Sayılan: {counts}
                {!blind && (
                  <>
                    {" · Sistem: "}{fmt(sys)}
                    {" · Fark: "}{fmt(variance)}
                  </>
                )}
              </div>
            </div>
          );
        })}
        {lines.length === 0 && !busy && <EmptyState message="Bu sayımda satır yok. ➕ Satır Üret ile bin content'ten oluşturun." />}
      </div>
      <div className="actions">
        <button className="outline" disabled={busy} onClick={() => action("generateLines", "Satırlar üretildi")}>
          ➕ Satır Üret
        </button>
        <button className="outline" disabled={busy} onClick={() => action("startRecount", "Recount başlatıldı")}>
          ⟳ Recount
        </button>
        <button className="primary big" disabled={busy} onClick={() => action("postSheet", "Sayım post edildi")}>
          ✅ Post
        </button>
      </div>
      {countLine && (
        <CountEntryModal
          line={countLine}
          blind={blind}
          onClose={() => setCountLine(null)}
          onSubmit={async (slot, qty) => {
            const ln = countLine;
            setCountLine(null);
            setBusy(true);
            setStatus("Sayım kaydediliyor...");
            const body = JSON.stringify({ counterSlot: slot, qty });
            const sheetNo = BcApi.firstValue(ln, "sheetNo") || no;
            const lineNo = Number(ln.lineNo);
            const r = await BcApi.post(
              `countSheetLines(sheetNo='${sheetNo}',lineNo=${lineNo})/Microsoft.NAV.recordCount`,
              body,
            );
            setBusy(false);
            setStatus(
              r.ok
                ? `PASS: Sayım kaydedildi (slot ${slot}, qty=${qty}) (HTTP ${r.httpCode})`
                : `HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
            );
            if (r.ok) reload();
          }}
        />
      )}
    </div>
  );
}

function CountEntryModal({
  line,
  blind,
  onClose,
  onSubmit,
}: {
  line: Row;
  blind: boolean;
  onClose: () => void;
  onSubmit: (slot: number, qty: number) => void;
}) {
  const qtyForSlot = (selectedSlot: number) => {
    const value = Number(line[`countedQty${selectedSlot}`] ?? 0);
    return value === 0 ? "" : String(value);
  };
  const [slot, setSlot] = useState<number>(1);
  const [qty, setQty] = useState(qtyForSlot(1));
  const sysQty = Number(line.systemQty ?? 0);
  const tracking = [
    line.lotNo ? `Lot: ${line.lotNo}` : "",
    line.serialNo ? `Seri: ${line.serialNo}` : "",
  ].filter(Boolean).join(" · ");
  const lpInfo = line.lpNo ? ` · LP: ${line.lpNo}` : "";
  const enteredCounts = [1, 2, 3]
    .map((countSlot) => ({ countSlot, value: Number(line[`countedQty${countSlot}`] ?? 0) }))
    .filter(({ value }) => value !== 0)
    .map(({ countSlot, value }) => `${countSlot}. sayım: ${value}`)
    .join(" · ");

  return (
    <Modal
      title="Sayım Gir"
      meta={`Item: ${line.itemNo} · Bin: ${line.binCode ?? "-"}${lpInfo}${tracking ? ` · ${tracking}` : ""}${blind ? "" : ` · Sistem: ${sysQty}`}`}
      onClose={onClose}
    >
      {enteredCounts && <div className="card-meta">Girilen miktarlar · {enteredCounts}</div>}
      <label className="field" htmlFor="counter-slot">Counter Slot</label>
      <select
        id="counter-slot"
        title="Hangi counter slot'a kaydedilecek"
        value={slot}
        onChange={(e) => {
          const nextSlot = Number(e.target.value);
          setSlot(nextSlot);
          setQty(qtyForSlot(nextSlot));
        }}
      >
        <option value={1}>Slot 1 (1. sayım)</option>
        <option value={2}>Slot 2 (2. sayım)</option>
        <option value={3}>Slot 3 (3. sayım)</option>
      </select>
      <div className="mt12">
        <NumberField label={blind ? "Sayılan miktar" : `Sayılan miktar (sistem: ${sysQty})`} value={qty} onChange={setQty} />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button className="primary" onClick={() => onSubmit(slot, Number(qty) || 0)}>
          Slot {slot}'e Kaydet
        </button>
      </div>
    </Modal>
  );
}
