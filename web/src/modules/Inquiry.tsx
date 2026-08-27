import React, { useState } from "react";
import * as BcApi from "../lib/bcApi";
import { EmptyState, Field, Pill, StatusText, Tabs } from "../ui/primitives";

type Row = Record<string, any>;
type TabKey = "item" | "bin";

export function Inquiry({ initialTab = "item" }: { initialTab?: TabKey }) {
  const [tab, setTab] = useState<TabKey>(initialTab);
  return (
    <div>
      <Tabs
        tabs={[
          { key: "item", label: "🔍 Item Inquiry" },
          { key: "bin", label: "🪣 Bin Inquiry" },
        ]}
        active={tab}
        onChange={(k) => setTab(k as TabKey)}
      />
      <div className="mt16">
        {tab === "item" ? <ItemInquiryTab /> : <BinInquiryTab />}
      </div>
    </div>
  );
}

// ============================================================
// Tab 1 — Item Inquiry (item card + LP-on-hand breakdown)
// ============================================================

function ItemInquiryTab() {
  const [q, setQ] = useState("");
  const [item, setItem] = useState<Row | null>(null);
  const [lines, setLines] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function search() {
    const term = q.trim();
    if (!term) return;
    setBusy(true);
    setStatus("Aranıyor...");
    setItem(null);
    setLines([]);

    // Try custom 'no' field first, then standard 'number'
    const r = await BcApi.getWithStandardFallback(
      `items?$filter=no eq '${term}'&$top=1`,
      `items?$filter=number eq '${term}'&$top=1`,
    );
    if (r.ok) {
      const arr = BcApi.parseValueArray(r.body);
      if (arr.length > 0) setItem(arr[0]);
    }
    const l = await BcApi.get(`licensePlateLines?$filter=itemNo eq '${term}'&$top=50`);
    const llines = l.ok ? BcApi.parseValueArray(l.body) : [];
    setLines(llines);
    setBusy(false);

    const found = (item ? 1 : (r.ok && BcApi.parseValueArray(r.body).length)) || 0;
    setStatus(
      !r.ok
        ? `HATA: Item arama başarısız (HTTP ${r.httpCode})`
        : found === 0
        ? `EMPTY: Item bulunamadı: ${term}`
        : `PASS: Item bulundu, ${llines.length} LP satırı`,
    );
  }

  return (
    <div>
      <div className="toolbar">
        <div className="lp-search">
          <input
            type="text"
            placeholder="Item No (örn. 1896-S, ITEM-LOT-1)"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && search()}
          />
        </div>
        <button className="primary" onClick={search} disabled={busy || q.trim().length === 0}>
          {busy ? "..." : "🔍 Ara"}
        </button>
      </div>
      <StatusText status={status} />
      {item && (
        <div className="card mt12">
          <div className="card-title">
            {String(item.no ?? item.number ?? "")} — {String(item.displayName ?? item.description ?? "")}
          </div>
          <div className="card-meta">
            UoM: {BcApi.firstValue(item, "baseUnitOfMeasure") || BcApi.firstValue(item, "baseUnitOfMeasureCode") || "-"}
            {item.itemCategoryCode && ` · Kategori: ${BcApi.firstValue(item, "itemCategoryCode")}`}
            {item.type && ` · Tip: ${BcApi.firstValue(item, "type")}`}
          </div>
        </div>
      )}
      {lines.length > 0 && (
        <>
          <h3 className="mt16">LP üzerinde bulunan ({lines.length})</h3>
          <div className="list">
            {lines.map((ln, idx) => (
              <div key={`${ln.lpNo}-${ln.lineNo ?? idx}`} className="card">
                <div className="row-between">
                  <div className="card-title">LP {String(ln.lpNo)} · {Number(ln.quantity ?? 0)} {BcApi.firstValue(ln, "unitOfMeasureCode")}</div>
                  <Pill text={`#${Number(ln.lineNo ?? 0)}`} tone="neutral" />
                </div>
                <div className="card-meta">
                  Lot: {BcApi.firstValue(ln, "lotNo") || "-"} · Serial: {BcApi.firstValue(ln, "serialNo") || "-"}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
      {!item && !busy && q && <EmptyState message="Item bulunamadı veya hiç LP'de değil." />}
    </div>
  );
}

// ============================================================
// Tab 2 — Bin Inquiry (bin info + LP-in-bin list)
// ============================================================

function BinInquiryTab() {
  const [loc, setLoc] = useState("SILVER");
  const [code, setCode] = useState("");
  const [bin, setBin] = useState<Row | null>(null);
  const [lps, setLps] = useState<Row[]>([]);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function search() {
    const l = loc.trim();
    const c = code.trim();
    if (!l || !c) return;
    setBusy(true);
    setStatus("Aranıyor...");
    setBin(null);
    setLps([]);

    const b = await BcApi.get(`bins?$filter=locationCode eq '${l}' and code eq '${c}'&$top=1`);
    if (b.ok) {
      const arr = BcApi.parseValueArray(b.body);
      if (arr.length > 0) setBin(arr[0]);
    }
    const lp = await BcApi.get(`licensePlates?$filter=locationCode eq '${l}' and binCode eq '${c}'&$top=50`);
    const lpList = lp.ok ? BcApi.parseValueArray(lp.body) : [];
    setLps(lpList);
    setBusy(false);

    const found = b.ok && BcApi.parseValueArray(b.body).length;
    setStatus(
      !b.ok
        ? `HATA: Bin arama başarısız (HTTP ${b.httpCode})`
        : !found
        ? `EMPTY: Bin bulunamadı: ${l}/${c}`
        : `PASS: Bin bulundu, ${lpList.length} LP içeriyor`,
    );
  }

  return (
    <div>
      <div className="toolbar">
        <div className="row" style={{ flex: 1, gap: 12 }}>
          <Field label="Location" value={loc} onChange={setLoc} placeholder="SILVER" />
          <Field label="Bin Code" value={code} onChange={setCode} placeholder="S-1-01" />
        </div>
        <button className="primary" onClick={search} disabled={busy || code.trim().length === 0}>
          {busy ? "..." : "🔍 Ara"}
        </button>
      </div>
      <StatusText status={status} />
      {bin && (
        <div className="card mt12">
          <div className="card-title">
            {String(bin.locationCode)}/{String(bin.code)}
            {bin.description && ` — ${String(bin.description)}`}
          </div>
          <div className="card-meta">
            Zone: {BcApi.firstValue(bin, "zoneCode") || "-"} · Ranking: {Number(bin.bin_Ranking ?? bin.binRanking ?? 0)}
          </div>
        </div>
      )}
      {lps.length > 0 && (
        <>
          <h3 className="mt16">Bu bin'de bulunan LP'ler ({lps.length})</h3>
          <div className="list">
            {lps.map((lp) => (
              <div key={String(lp.no)} className="card">
                <div className="row-between">
                  <div className="card-title">{String(lp.no)}</div>
                  <Pill text={String(lp.status ?? "")} tone={String(lp.status) === "Built" ? "ok" : "neutral"} />
                </div>
                <div className="card-meta">
                  Template: {BcApi.firstValue(lp, "templateCode")} · SSCC: {BcApi.firstValue(lp, "sscc") || "-"}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
      {!bin && !busy && code && <EmptyState message="Bin bulunamadı veya boş." />}
    </div>
  );
}
