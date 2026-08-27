import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { getDefaultPrinter } from "./Printers";
import { friendlyQcStatus, isQcBlocked, extractInspectionNo } from "../lib/qcErrorParser";
import { navigateTo } from "../main";
import { DocHeader, EmptyState, Modal, NumberField, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

export function Picking() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get("picks?$top=30&$select=no,locationCode,assignedUserId,status,sourceNo,dueDate,percentComplete");
    setLoading(false);
    const arr = r.ok ? BcApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Pick listesi alınamadı (HTTP ${r.httpCode})`
        : arr.length === 0
        ? `EMPTY: Açık pick yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} pick (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  if (selected) {
    return <PickDocument no={selected} onBack={() => { setSelected(null); load(); }} />;
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
              Lokasyon: {BcApi.firstValue(d, "locationCode")} · Atanan: {BcApi.firstValue(d, "assignedUserId") || "-"} · Kaynak: {BcApi.firstValue(d, "sourceNo") || "-"}
            </div>
          </div>
        ))}
        {rows.length === 0 && !loading && <EmptyState message="Açık pick yok." />}
      </div>
    </div>
  );
}

function PickDocument({ no, onBack }: { no: string; onBack: () => void }) {
  const [header, setHeader] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [qcBlock, setQcBlock] = useState<{ inspectionNo: string | null; raw: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [qtyLine, setQtyLine] = useState<Row | null>(null);
  const [shortLine, setShortLine] = useState<Row | null>(null);
  const [shipLp, setShipLp] = useState<string | null>(null);

  function handleError(body: string, httpCode: number) {
    const msg = BcApi.errorMessage(body);
    if (isQcBlocked(msg)) {
      setQcBlock({ inspectionNo: extractInspectionNo(msg), raw: msg });
    }
    setStatus(friendlyQcStatus(msg, httpCode));
  }

  async function reload() {
    setBusy(true);
    const h = await BcApi.get(`picks('${no}')`);
    if (h.ok) setHeader(JSON.parse(h.body));
    const l = await BcApi.get(`pickLines?$filter=no eq '${no}'&$top=200`);
    setLines(l.ok ? BcApi.parseValueArray(l.body) : []);
    setBusy(false);
  }
  useEffect(() => { reload(); }, [no]);

  async function action(name: string, body: string, okMsg: string, onOk?: (body: string) => void) {
    setBusy(true);
    setStatus(`${name}…`);
    const r = await BcApi.boundAction("picks", no, name, body);
    setBusy(false);
    if (r.ok) {
      setStatus(`PASS: ${okMsg} (HTTP ${r.httpCode})`);
      setQcBlock(null);
      onOk?.(r.body);
      reload();
    } else {
      handleError(r.body, r.httpCode);
    }
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Pick Listesi</button>
      <DocHeader
        title={no}
        subtitle={`Lokasyon: ${BcApi.firstValue(header, "locationCode")} · Atanan: ${BcApi.firstValue(header, "assignedUserId") || "-"}\nDurum: ${BcApi.firstValue(header, "status")}${shipLp ? `\nAktif Ship LP: ${shipLp}` : ""}`}
      />
      {qcBlock && (
        <div className="banner-warn">
          🔬 <b>Quality Inspection bekliyor</b>
          {qcBlock.inspectionNo && (
            <> — denetim <code>{qcBlock.inspectionNo}</code></>
          )}
          . Bu pick'in lot/serial'i şu an blokda; denetim tamamlanmadan register edilemez.
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
      <h3 className="mt16">Satırlar ({lines.length})</h3>
      <div className="list">
        {lines.map((ln) => (
          <div key={String(ln.lineNo)} className="card">
            <div className="row-between">
              <div className="card-title clickable" onClick={() => setQtyLine(ln)}>
                {String(ln.itemNo)}
              </div>
              <button className="outline small" disabled={busy} onClick={() => setShortLine(ln)}>
                ⚠ Short
              </button>
            </div>
            <div className="card-meta">
              Action: {BcApi.firstValue(ln, "actionType")} · Bin: {BcApi.firstValue(ln, "binCode")} · İşlenecek: {Number(ln.qtyToHandle ?? 0)} / {Number(ln.qty ?? 0)}
            </div>
          </div>
        ))}
        {lines.length === 0 && !busy && <EmptyState message="Bu pick'te satır yok." />}
      </div>
      <div className="actions">
        <button className="outline" disabled={busy} onClick={() => action("assignToMe", "{}", "Pick atandı")}>
          ✋ Bana Ata
        </button>
        {shipLp === null ? (
          <button
            className="outline"
            disabled={busy}
            onClick={() =>
              action(
                "startShippingLP",
                JSON.stringify({ lpTemplateCode: "PALLET-EUR" }),
                "Shipping LP başladı",
                (body) => setShipLp(BcApi.scalarValue(body)),
              )
            }
          >
            🏗️ Ship LP Başlat
          </button>
        ) : (
          <button
            className="outline"
            disabled={busy}
            onClick={() =>
              action(
                "stopShippingLPToPrinter",
                JSON.stringify({ lpNo: shipLp, printLabel: true, printerId: getDefaultPrinter() }),
                "Shipping LP kapandı + SSCC",
                () => setShipLp(null),
              )
            }
          >
            🔚 Ship LP Kapat ({shipLp})
          </button>
        )}
        <button className="primary big" disabled={busy} onClick={() => action("register", "{}", "Pick register edildi")}>
          ✅ Register Pick
        </button>
      </div>
      {qtyLine && (
        <PickQtyModal
          line={qtyLine}
          onClose={() => setQtyLine(null)}
          onSubmit={async (qty) => {
            setQtyLine(null);
            setBusy(true);
            setStatus("Satır güncelleniyor...");
            const actType = BcApi.firstValue(qtyLine, "activityType") || "Pick";
            const r = await BcApi.patch(
              `pickLines(activityType='${actType}',no='${no}',lineNo=${qtyLine.lineNo})`,
              JSON.stringify({ qtyToHandle: qty }),
            );
            setBusy(false);
            if (r.ok) {
              setStatus(`PASS: Satır güncellendi qty=${qty} (HTTP ${r.httpCode})`);
              setQcBlock(null);
              reload();
            } else {
              handleError(r.body, r.httpCode);
            }
          }}
        />
      )}
      {shortLine && (
        <ShortPickModal
          line={shortLine}
          onClose={() => setShortLine(null)}
          onSubmit={(qty, reason) => {
            const ln = shortLine;
            setShortLine(null);
            action(
              "markShort",
              JSON.stringify({ lineNo: Number(ln.lineNo), qty, reasonCode: reason }),
              `Short pick işlendi (qty=${qty}, reason=${reason})`,
            );
          }}
        />
      )}
    </div>
  );
}

function ShortPickModal({
  line,
  onClose,
  onSubmit,
}: {
  line: Row;
  onClose: () => void;
  onSubmit: (qty: number, reasonCode: string) => void;
}) {
  const [qty, setQty] = useState(String(Number(line.qtyToHandle ?? line.qty ?? 0)));
  const [reason, setReason] = useState("NO_STOCK");
  return (
    <Modal
      title="Kısa Pick (Short)"
      meta={`Item: ${line.itemNo} · Bin: ${line.binCode ?? "-"} · Outstanding: ${Number(line.qtyToHandle ?? line.qty ?? 0)}`}
      onClose={onClose}
    >
      <NumberField label="Eksik miktar" value={qty} onChange={setQty} />
      <div className="mt12">
        <label className="field" htmlFor="short-reason">Sebep</label>
        <select
          id="short-reason"
          title="Short pick sebebi"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        >
          <option value="NO_STOCK">NO_STOCK — Bin'de yok</option>
          <option value="DAMAGED">DAMAGED — Hasarlı</option>
          <option value="WRONG_BIN">WRONG_BIN — Yanlış bin</option>
          <option value="EXPIRED">EXPIRED — Vadesi geçmiş</option>
          <option value="OTHER">OTHER — Diğer</option>
        </select>
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onSubmit(Number(qty) || 0, reason)}
          disabled={(Number(qty) || 0) <= 0}
        >
          Short Olarak İşaretle
        </button>
      </div>
    </Modal>
  );
}

function PickQtyModal({
  line,
  onClose,
  onSubmit,
}: {
  line: Row;
  onClose: () => void;
  onSubmit: (qty: number) => void;
}) {
  const [qty, setQty] = useState(String(Number(line.qtyToHandle ?? line.qty ?? 1)));
  return (
    <Modal
      title="Toplama Miktarı"
      meta={`Item: ${line.itemNo} · Bin: ${line.binCode ?? "-"}`}
      onClose={onClose}
    >
      <NumberField label="İşlenecek qty" value={qty} onChange={setQty} />
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button className="primary" onClick={() => onSubmit(Number(qty) || 0)}>Onayla</button>
      </div>
    </Modal>
  );
}
