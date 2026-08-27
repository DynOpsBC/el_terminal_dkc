import React, { useEffect, useState } from "react";
import * as QmApi from "../lib/qmApi";
import { DocHeader, EmptyState, Field, Modal, Pill, StatusText } from "../ui/primitives";

type Row = Record<string, any>;

/**
 * Microsoft Quality Management module (BC v28+ first-party extension).
 * Talks directly to api/microsoft/qualityManagement/v1.0/qualityInspections.
 * Operator can list open inspections, drill in, record test values,
 * finish/reopen, and trigger Block/Unblock on lots/serials/packages.
 */
export function QualityManagement() {
  const [rows, setRows] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<Row | null>(null);
  const [openOnly, setOpenOnly] = useState(true);

  async function load() {
    setLoading(true);
    setStatus("Yükleniyor...");
    const filter = openOnly ? `&$filter=status eq 'Open'` : "";
    const r = await QmApi.get(`qualityInspections?$top=50${filter}&$orderby=systemCreatedAt desc`);
    setLoading(false);
    const arr = r.ok ? QmApi.parseValueArray(r.body) : [];
    setRows(arr);
    setStatus(
      !r.ok
        ? `HATA: QM inspections alınamadı (HTTP ${r.httpCode}) — ${QmApi.errorMessage(r.body).slice(0, 120)}`
        : arr.length === 0
        ? `EMPTY: ${openOnly ? "Açık" : ""} inspection yok (HTTP ${r.httpCode})`
        : `PASS: ${arr.length} inspection (HTTP ${r.httpCode})`,
    );
  }
  useEffect(() => { load(); }, [openOnly]);

  if (selected) {
    return <InspectionDetail row={selected} onBack={() => { setSelected(null); load(); }} />;
  }

  return (
    <div>
      <div className="toolbar">
        <button className="primary" onClick={load} disabled={loading}>
          {loading ? "..." : "🔄 Yenile"}
        </button>
        <button
          className={`chip ${openOnly ? "active" : ""}`}
          onClick={() => setOpenOnly(!openOnly)}
        >
          {openOnly ? "Sadece Açık" : "Tümü"}
        </button>
      </div>
      <StatusText status={status} />
      <div className="list">
        {rows.map((d) => {
          const sval = String(d.status ?? "");
          const tone = sval === "Finished" ? "ok" : sval === "Cancelled" ? "warn" : "neutral";
          return (
            <div key={String(d.systemIDOfInspection)} className="card clickable" onClick={() => setSelected(d)}>
              <div className="row-between">
                <div className="card-title">
                  {String(d.inspectionNo)} · {QmApi.firstValue(d, "templateCode") || "—"}
                </div>
                <Pill text={sval || "Open"} tone={tone as "ok" | "warn" | "neutral"} />
              </div>
              <div className="card-meta">
                {String(d.description ?? "")}
                <br />
                Item: {QmApi.firstValue(d, "sourceItemNo") || "—"}
                {d.sourceLotNo && ` · Lot: ${QmApi.firstValue(d, "sourceLotNo")}`}
                {d.sourceSerialNo && ` · SN: ${QmApi.firstValue(d, "sourceSerialNo")}`}
                {d.sourceQuantity ? ` · Qty: ${Number(d.sourceQuantity)}` : ""}
                {d.resultCode && <> · Sonuç: <b>{QmApi.firstValue(d, "resultCode")}</b></>}
              </div>
            </div>
          );
        })}
        {rows.length === 0 && !loading && (
          <EmptyState message={openOnly ? "Açık quality inspection yok." : "Hiç quality inspection yok."} />
        )}
      </div>
    </div>
  );
}

// ============================================================
// Inspection Detail — test values + finish + block actions
// ============================================================

function InspectionDetail({ row, onBack }: { row: Row; onBack: () => void }) {
  const [insp, setInsp] = useState<Row>(row);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [showFinish, setShowFinish] = useState(false);
  const [showTest, setShowTest] = useState(false);

  const systemId = String(insp.systemIDOfInspection ?? row.systemIDOfInspection);
  const sval = String(insp.status ?? "");
  const isOpen = sval === "Open" || sval === "InProgress" || sval === "";
  const lot = QmApi.firstValue(insp, "sourceLotNo");
  const serial = QmApi.firstValue(insp, "sourceSerialNo");
  const pkg = QmApi.firstValue(insp, "sourcePackageNo");

  async function reload() {
    setBusy(true);
    const r = await QmApi.get(`qualityInspections(${QmApi.inspectionKey(systemId)})`);
    setBusy(false);
    if (r.ok) {
      try {
        setInsp(JSON.parse(r.body));
      } catch {
        /* keep previous */
      }
    }
  }

  async function action(name: string, body: string, okMsg: string) {
    setBusy(true);
    setStatus(`${name}…`);
    const r = await QmApi.boundAction(systemId, name, body);
    setBusy(false);
    setStatus(
      r.ok
        ? `PASS: ${okMsg} (HTTP ${r.httpCode})`
        : `HATA: ${QmApi.errorMessage(r.body)} (HTTP ${r.httpCode})`,
    );
    if (r.ok) reload();
  }

  return (
    <div>
      <button className="ghost" onClick={onBack}>‹ Inspection Listesi</button>
      <DocHeader
        title={`${insp.inspectionNo} · ${QmApi.firstValue(insp, "templateCode") || "—"}`}
        subtitle={
          `${QmApi.firstValue(insp, "description")}\n` +
          `Item: ${QmApi.firstValue(insp, "sourceItemNo") || "—"}` +
          (lot ? ` · Lot: ${lot}` : "") +
          (serial ? ` · SN: ${serial}` : "") +
          (pkg ? ` · Pkg: ${pkg}` : "") +
          `\nDurum: ${sval} · Sonuç: ${QmApi.firstValue(insp, "resultCode") || "—"}`
        }
      />
      <StatusText status={status} />

      <h3 className="mt16">Aksiyonlar</h3>
      <div className="actions">
        <button className="outline" disabled={busy || !isOpen} onClick={() => setShowTest(true)}>
          ➕ Test Değeri Gir
        </button>
        <button className="primary big" disabled={busy || !isOpen} onClick={() => setShowFinish(true)}>
          ✅ Inspection'ı Bitir
        </button>
        <button className="outline" disabled={busy || isOpen} onClick={() => action("ReopenInspection", "{}", "Inspection geri açıldı")}>
          ↩️ Geri Aç
        </button>
        <button className="outline" disabled={busy} onClick={() => action("CreateReinspection", "{}", "Yeniden inceleme oluşturuldu")}>
          🔁 Reinspection
        </button>
      </div>

      <h3 className="mt16">Lot / Serial / Package Bloklama</h3>
      <div className="actions">
        <button className="outline danger-outline" disabled={busy || !lot} onClick={() => action("BlockLot", "{}", `Lot ${lot} bloklandı`)}>
          🔒 Block Lot
        </button>
        <button className="outline" disabled={busy || !lot} onClick={() => action("UnBlockLot", "{}", `Lot ${lot} açıldı`)}>
          🔓 Unblock Lot
        </button>
        <button className="outline danger-outline" disabled={busy || !serial} onClick={() => action("BlockSerial", "{}", `SN ${serial} bloklandı`)}>
          🔒 Block SN
        </button>
        <button className="outline" disabled={busy || !serial} onClick={() => action("UnBlockSerial", "{}", `SN ${serial} açıldı`)}>
          🔓 Unblock SN
        </button>
        <button className="outline danger-outline" disabled={busy || !pkg} onClick={() => action("BlockPackage", "{}", `Pkg ${pkg} bloklandı`)}>
          🔒 Block Pkg
        </button>
        <button className="outline" disabled={busy || !pkg} onClick={() => action("UnBlockPackage", "{}", `Pkg ${pkg} açıldı`)}>
          🔓 Unblock Pkg
        </button>
      </div>

      {showTest && (
        <SetTestValueModal
          onClose={() => setShowTest(false)}
          onSubmit={(testCode, testValue) => {
            setShowTest(false);
            action(
              "SetTestValue",
              JSON.stringify({ testCode, testValue }),
              `Test ${testCode} = ${testValue} kaydedildi`,
            );
          }}
        />
      )}
      {showFinish && (
        <FinishInspectionModal
          onClose={() => setShowFinish(false)}
          onSubmit={() => {
            setShowFinish(false);
            action("FinishInspection", "{}", "Inspection bitirildi");
          }}
        />
      )}
    </div>
  );
}

function SetTestValueModal({
  onClose,
  onSubmit,
}: {
  onClose: () => void;
  onSubmit: (testCode: string, testValue: string) => void;
}) {
  const [code, setCode] = useState("");
  const [value, setValue] = useState("");
  return (
    <Modal title="Test Değeri Gir" meta="Inspection template'deki test koduyla ölçülen değeri kaydet" onClose={onClose}>
      <Field label="Test Code" value={code} onChange={setCode} placeholder="ÖRN: HUMIDITY" />
      <div className="mt12">
        <Field label="Test Value" value={value} onChange={setValue} placeholder="ÖRN: 42.5" />
      </div>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button
          className="primary"
          onClick={() => onSubmit(code.trim(), value.trim())}
          disabled={code.trim().length === 0 || value.trim().length === 0}
        >
          Kaydet
        </button>
      </div>
    </Modal>
  );
}

function FinishInspectionModal({
  onClose,
  onSubmit,
}: {
  onClose: () => void;
  onSubmit: () => void;
}) {
  return (
    <Modal
      title="Inspection'ı Bitir"
      meta="Template kurallarına göre BC otomatik resultCode atayacak. Devam?"
      onClose={onClose}
    >
      <p className="card-meta">
        Tüm test değerlerinin girildiğinden emin olun. Bitirme sonrası Block/Unblock action'ları
        result code'a göre BC tarafında otomatik tetiklenebilir.
      </p>
      <div className="actions" style={{ borderTop: "none", marginTop: 16 }}>
        <button className="outline" onClick={onClose}>İptal</button>
        <button className="primary" onClick={onSubmit}>Bitir</button>
      </div>
    </Modal>
  );
}
