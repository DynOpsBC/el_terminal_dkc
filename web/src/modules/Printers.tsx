import React, { useEffect, useState } from "react";
import * as BcApi from "../lib/bcApi";
import { DocHeader, EmptyState, Field, Modal, Pill, StatusText } from "../ui/primitives";

type Printer = {
  code: string;
  description?: string;
  locationCode?: string;
  format?: string;
  printerHandle?: string;
  hostname?: string;
  port?: number;
  active?: boolean;
  defaultCopies?: number;
  enableBcReports?: boolean;
  paperWidthMm?: number;
  paperHeightMm?: number;
  stationId?: string;
  discoveredByAgent?: boolean;
  agentStatus?: string;
  lastStatusAt?: string | null;
  lastStatusMessage?: string;
  agentVersion?: string;
  lastSeenAt?: string | null;
  tokenIssuedAt?: string | null;
  comment?: string;
};

export type PrinterUsage = "label" | "document";
const PREF_KEYS: Record<PrinterUsage, string> = {
  label: "bcwms.defaultPrinter",
  document: "bcwms.defaultDocumentPrinter",
};
export const getDefaultPrinter = (usage: PrinterUsage = "label"): string => localStorage.getItem(PREF_KEYS[usage]) ?? "";
export const setDefaultPrinter = (code: string, usage: PrinterUsage = "label"): void => {
  if (code) localStorage.setItem(PREF_KEYS[usage], code);
  else localStorage.removeItem(PREF_KEYS[usage]);
};

export function Printers() {
  const [rows, setRows] = useState<Printer[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState<Printer | null>(null);
  const [defaultLabelCode, setDefaultLabelCode] = useState(getDefaultPrinter("label"));
  const [defaultDocumentCode, setDefaultDocumentCode] = useState(getDefaultPrinter("document"));

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const r = await BcApi.get(`printers?$top=100&$orderby=code`);
    setLoading(false);
    const arr = r.ok ? (BcApi.parseValueArray(r.body) as unknown as Printer[]) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: Printer listesi alınamadı (HTTP ${r.httpCode}) — ${BcApi.errorMessage(r.body).slice(0, 140)}`
        : arr.length === 0
        ? `EMPTY: kayıtlı printer yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} printer (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, []);

  function chooseDefault(code: string, usage: PrinterUsage) {
    setDefaultPrinter(code, usage);
    if (usage === "label") setDefaultLabelCode(code);
    else setDefaultDocumentCode(code);
  }

  async function testPrint(p: Printer) {
    const r = await BcApi.boundAction("printers", `'${p.code}'`, "testPrint", "{}");
    if (r.ok) alert(`Self-test job ${p.code} için kuyruğa alındı.`);
    else alert(`HATA: ${BcApi.errorMessage(r.body)}`);
  }

  return (
    <div>
      <DocHeader
        title="🖨 Yazıcılar"
        subtitle="Windows ajanının eşitlediği yazıcılardan bu istasyon için ayrı etiket ve belge varsayılanlarını seçin."
      />
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>{loading ? "..." : "🔄 Yenile"}</button>
        <button title="Yalnız eski SelfHosted/PrintNode kurulumları için" onClick={() => setEditing({ code: "", active: true, enableBcReports: false, format: "ZPL", port: 9100, defaultCopies: 1 })}>+ Manuel (Legacy)</button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.length === 0 && status.startsWith("EMPTY") && (
          <EmptyState message="Henüz yazıcı yok — Windows Print Agent'ta yazıcıları yenileyip Buluta Eşitle'yi çalıştırın." />
        )}
        {rows.map((p) => (
          <div key={p.code} className="card">
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div>
                <div style={{ fontWeight: 600 }}>
                  {p.code} {defaultLabelCode === p.code && <Pill text="Etiket" tone="ok" />}
                  {defaultDocumentCode === p.code && <Pill text="Belge" tone="ok" />}
                  {p.enableBcReports && <Pill text="BC Reports" tone="ok" />}
                  {p.agentStatus === "Online" && <Pill text="Agent Online" tone="ok" />}
                  {p.agentStatus && p.agentStatus !== "Online" && <Pill text={p.agentStatus} tone="warn" />}
                  {!p.active && <Pill text="Pasif" tone="warn" />}
                </div>
                <div style={{ fontSize: 12, color: "var(--text-muted)" }}>
                  {p.description ?? ""} · {p.format ?? "-"} · {p.printerHandle ?? p.hostname ?? "-"}
                  {p.stationId ? ` · ${p.stationId}` : ""} · son durum {p.lastStatusAt ?? p.lastSeenAt ?? "—"}
                </div>
              </div>
              <div style={{ display: "flex", gap: 6 }}>
                <button disabled={!p.active || p.format !== "ZPL"} onClick={() => chooseDefault(p.code, "label")}>{defaultLabelCode === p.code ? "✓ Etiket" : "Etiket"}</button>
                <button disabled={!p.active || p.format !== "PDF"} onClick={() => chooseDefault(p.code, "document")}>{defaultDocumentCode === p.code ? "✓ Belge" : "Belge"}</button>
                <button onClick={() => setEditing(p)}>Düzenle</button>
                <button disabled={!p.active || p.format !== "ZPL"} onClick={() => testPrint(p)}>🧪 ZPL Test</button>
              </div>
            </div>
          </div>
        ))}
      </div>
      {editing && (
        <PrinterEditor
          row={editing}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); load(); }}
        />
      )}
    </div>
  );
}

function PrinterEditor({ row, onClose, onSaved }: { row: Printer; onClose: () => void; onSaved: () => void }) {
  const isNew = !row.code || row.code.length === 0;
  const [draft, setDraft] = useState<Printer>({ ...row });
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");

  async function save() {
    if (!draft.code) { setMsg("Code zorunlu"); return; }
    setBusy(true);
    setMsg("");
    const body = JSON.stringify({
      code: draft.code,
      description: draft.description ?? "",
      locationCode: draft.locationCode ?? "",
      format: draft.format ?? "ZPL",
      printerHandle: draft.printerHandle ?? "",
      hostname: draft.hostname ?? "",
      port: draft.port ?? 9100,
      active: draft.active ?? true,
      defaultCopies: draft.defaultCopies ?? 1,
      enableBcReports: draft.format === "PDF" && (draft.enableBcReports ?? false),
      paperWidthMm: draft.paperWidthMm ?? 0,
      paperHeightMm: draft.paperHeightMm ?? 0,
      comment: draft.comment ?? "",
    });
    const r = isNew
      ? await BcApi.post("printers", body)
      : await BcApi.patch(`printers('${draft.code}')`, body);
    setBusy(false);
    if (r.ok) onSaved();
    else setMsg(BcApi.errorMessage(r.body).slice(0, 200));
  }

  return (
    <Modal title={isNew ? "Yeni Printer" : `Printer ${row.code}`} onClose={onClose}>
      <Field label="Code" value={draft.code} onChange={(v) => setDraft({ ...draft, code: v.toUpperCase() })} />
      <Field label="Açıklama" value={draft.description ?? ""} onChange={(v) => setDraft({ ...draft, description: v })} />
      <Field label="Location Code" value={draft.locationCode ?? ""} onChange={(v) => setDraft({ ...draft, locationCode: v.toUpperCase() })} />
      <div>
        <label className="field">Format</label>
        <select
          aria-label="Format"
          value={draft.format ?? "ZPL"}
          onChange={(e) => {
            const format = e.target.value;
            setDraft({ ...draft, format, enableBcReports: format === "PDF" ? draft.enableBcReports : false });
          }}
        >
          <option value="ZPL">ZPL (Zebra)</option>
          <option value="PDF">PDF</option>
          <option value="ESCPOS">ESC/POS</option>
          <option value="RAW">Raw</option>
        </select>
      </div>
      <Field label="Printer Handle (OS adı)" value={draft.printerHandle ?? ""} onChange={(v) => setDraft({ ...draft, printerHandle: v })} />
      <Field label="Hostname / IP" value={draft.hostname ?? ""} onChange={(v) => setDraft({ ...draft, hostname: v })} />
      <Field label="Port" type="number" value={String(draft.port ?? 9100)} onChange={(v) => setDraft({ ...draft, port: Number(v) })} />
      <Field label="Default Copies" type="number" value={String(draft.defaultCopies ?? 1)} onChange={(v) => setDraft({ ...draft, defaultCopies: Number(v) })} />
      <Field label="Kağıt genişliği (mm, A4 için 0)" type="number" value={String(draft.paperWidthMm ?? 0)} onChange={(v) => setDraft({ ...draft, paperWidthMm: Math.max(0, Number(v)) })} />
      <Field label="Kağıt yüksekliği (mm, A4 için 0)" type="number" value={String(draft.paperHeightMm ?? 0)} onChange={(v) => setDraft({ ...draft, paperHeightMm: Math.max(0, Number(v)) })} />
      <div>
        <label className="field" htmlFor="printer-bc-reports">Standart BC raporlarında göster</label>
        <input
          id="printer-bc-reports"
          type="checkbox"
          checked={draft.enableBcReports ?? false}
          disabled={draft.format !== "PDF"}
          onChange={(e) => setDraft({ ...draft, enableBcReports: e.target.checked })}
        />
      </div>
      <div>
        <label className="field" htmlFor="printer-active">Aktif</label>
        <input
          id="printer-active"
          type="checkbox"
          checked={draft.active ?? true}
          onChange={(e) => setDraft({ ...draft, active: e.target.checked })}
        />
      </div>
      <Field label="Not" value={draft.comment ?? ""} onChange={(v) => setDraft({ ...draft, comment: v })} />
      {msg && <div style={{ color: "var(--text-danger)", fontSize: 12 }}>{msg}</div>}
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 8, marginTop: 12 }}>
        <button onClick={onClose}>Vazgeç</button>
        <button className="primary" onClick={save} disabled={busy}>{busy ? "..." : "Kaydet"}</button>
      </div>
    </Modal>
  );
}
