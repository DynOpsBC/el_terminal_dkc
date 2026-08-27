import { useEffect, useMemo, useState } from "react";
import { assignDoc, createMultiPick, listenBridge, requestRefresh } from "../../al-bridge/ControlAddInBridge";
import { type DocType, type OpsData, normalizeOps, seedOps } from "./data/opsData";
import { pickDict } from "./i18n";

const TABS: DocType[] = ["pick", "putaway", "shipment", "count"];

export function OpsConsoleApp() {
  const [data, setData] = useState<OpsData>(seedOps());
  const [locale, setLocale] = useState("tr");
  const [tab, setTab] = useState<DocType | "orders">("pick");
  // ELOG multi akışı: sipariş seçimi + atanacak kullanıcı + sonuç bildirimi.
  const [selectedOrders, setSelectedOrders] = useState<Set<string>>(new Set());
  const [pickUser, setPickUser] = useState("");
  const [notice, setNotice] = useState("");
  const [noticeType, setNoticeType] = useState<"pending" | "success" | "error">("pending");
  const [lastPickRequest, setLastPickRequest] = useState<{ orders: string; user: string } | null>(null);
  const t = useMemo(() => pickDict(locale), [locale]);

  // Auto-clear notice after 5s for success/error messages
  useEffect(() => {
    if (noticeType !== "pending" && notice) {
      const timer = setTimeout(() => {
        setNotice("");
        setNoticeType("pending");
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [notice, noticeType]);

  useEffect(() => {
    const off = listenBridge((m) => {
      if (m.type === "setData") {
        setData(normalizeOps(m.payload));
        setSelectedOrders(new Set());
      }
      if (m.type === "setLocale") setLocale(m.locale);
      if (m.type === "notifyResult") {
        const r = (m.payload ?? {}) as { pickNo?: string; shipmentNo?: string; error?: string };
        if (r.error) {
          setNotice(`❌ ${r.error}`);
          setNoticeType("error");
        } else if (r.pickNo) {
          setNotice(`✅ ${r.pickNo} · ${r.shipmentNo ?? ""}`);
          setNoticeType("success");
          // Clear selected orders after successful creation
          setSelectedOrders(new Set());
        }
      }
    });
    requestRefresh();
    return () => { off(); };
  }, []);

  const s = data.summary;
  const tiles: Array<{ key: string; label: string; value: number; accent: string }> = [
    { key: "receipts", label: t.tiles.receipts, value: s.receipts, accent: "#26A65B" },
    { key: "putaways", label: t.tiles.putaways, value: s.putaways, accent: "#2D9CDB" },
    { key: "picks", label: t.tiles.picks, value: s.picks, accent: "#6C5CE7" },
    { key: "shipments", label: t.tiles.shipments, value: s.shipments, accent: "#E2873B" },
    { key: "counts", label: t.tiles.counts, value: s.counts, accent: "#9B59B6" },
    { key: "unassigned", label: t.tiles.unassigned, value: s.unassigned, accent: "#E74C3C" },
    { key: "inProgress", label: t.tiles.inProgress, value: s.inProgress, accent: "#0EA5A5" },
  ];

  const toggleOrder = (no: string) => {
    setSelectedOrders((prev) => {
      const next = new Set(prev);
      if (next.has(no)) next.delete(no); else next.add(no);
      return next;
    });
  };

  const onCreatePick = () => {
    if (selectedOrders.size === 0) return;
    const orderCsv = Array.from(selectedOrders).join(",");
    setNotice("⏳");
    setNoticeType("pending");
    setLastPickRequest({ orders: orderCsv, user: pickUser });
    createMultiPick(orderCsv, pickUser);
  };

  const onRetryPick = () => {
    if (!lastPickRequest) return;
    setNotice("⏳");
    setNoticeType("pending");
    createMultiPick(lastPickRequest.orders, lastPickRequest.user);
  };

  return (
    <div className="ops">
      <header className="ops-top">
        <h1>{t.title}</h1>
        <div className="ops-notice-group">
          {notice && (
            <span className={"ops-notice s-" + noticeType}>
              {notice}
              {noticeType === "error" && lastPickRequest && (
                <button className="ops-notice-retry" onClick={onRetryPick}>↻</button>
              )}
            </span>
          )}
        </div>
        <button className="ops-btn" onClick={() => requestRefresh()}>↻ {t.refresh}</button>
      </header>

      <section className="ops-tiles">
        {tiles.map((tile) => (
          <div className="ops-tile" key={tile.key} style={{ borderTopColor: tile.accent }}>
            <div className="ops-tile-val" style={{ color: tile.accent }}>{tile.value}</div>
            <div className="ops-tile-lbl">{tile.label}</div>
          </div>
        ))}
      </section>

      <nav className="ops-tabs">
        {TABS.map((tp) => (
          <button
            key={tp}
            className={"ops-tab" + (tab === tp ? " active" : "")}
            onClick={() => setTab(tp)}
          >
            {t.tabs[tp]} <span className="ops-count">{data.docs[tp].length}</span>
          </button>
        ))}
        <button
          className={"ops-tab" + (tab === "orders" ? " active" : "")}
          onClick={() => setTab("orders")}
        >
          {t.tabs.orders} <span className="ops-count">{data.orders.length}</span>
        </button>
      </nav>

      {tab === "orders" ? (
        <>
          <div className="ops-orderbar">
            <span>{selectedOrders.size} {t.ord.selected}</span>
            <select className="ops-select" value={pickUser} onChange={(e) => setPickUser(e.target.value)}>
              <option value="">{t.ord.assignTo}…</option>
              {data.users.map((u) => (
                <option key={u} value={u}>{u}</option>
              ))}
            </select>
            <button className="ops-btn primary" disabled={selectedOrders.size === 0} onClick={onCreatePick}>
              📦 {t.ord.createPick}
            </button>
          </div>
          <table className="ops-table">
            <thead>
              <tr>
                <th></th>
                <th>{t.col.no}</th>
                <th>{t.ord.customer}</th>
                <th>{t.ord.location}</th>
                <th>{t.ord.lines}</th>
                <th>{t.ord.qty}</th>
                <th>{t.col.status}</th>
              </tr>
            </thead>
            <tbody>
              {data.orders.length === 0 && (
                <tr><td className="ops-empty" colSpan={7}>{t.empty}</td></tr>
              )}
              {data.orders.map((o) => (
                <tr key={o.no} className={selectedOrders.has(o.no) ? "ops-selected" : ""} onClick={() => toggleOrder(o.no)}>
                  <td><input type="checkbox" checked={selectedOrders.has(o.no)} onChange={() => toggleOrder(o.no)} onClick={(e) => e.stopPropagation()} /></td>
                  <td className="ops-mono">{o.no}</td>
                  <td>{o.customer}</td>
                  <td className="ops-mono">{o.location}</td>
                  <td>{o.lines}</td>
                  <td>{o.qty}</td>
                  <td><span className={"ops-badge s-" + o.status.toLowerCase()}>{o.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      ) : (
        <table className="ops-table">
          <thead>
            <tr>
              <th>{t.col.no}</th>
              <th>{t.col.source}</th>
              <th>{t.col.status}</th>
              <th>{t.col.progress}</th>
              <th>{t.col.assignee}</th>
              <th>{t.col.assign}</th>
            </tr>
          </thead>
          <tbody>
            {data.docs[tab].length === 0 && (
              <tr><td className="ops-empty" colSpan={6}>{t.empty}</td></tr>
            )}
            {data.docs[tab].map((d) => (
              <tr key={d.no} className={d.assignedUserId ? "" : "ops-unassigned"}>
                <td className="ops-mono">{d.no}</td>
                <td className="ops-mono">{d.sourceNo || "—"}</td>
                <td><span className={"ops-badge s-" + d.status.toLowerCase()}>{d.status}</span></td>
                <td>
                  <div className="ops-bar"><div className="ops-bar-fill" style={{ width: `${Math.max(0, Math.min(100, d.percent))}%` }} /></div>
                  <span className="ops-pct">%{Math.round(d.percent)}</span>
                </td>
                <td>{d.assignedUserId || <em className="ops-dim">{t.unassigned}</em>}</td>
                <td>
                  <select
                    className="ops-select"
                    value={d.assignedUserId}
                    onChange={(e) => assignDoc(tab, d.no, e.target.value)}
                  >
                    <option value="">{t.unassigned}</option>
                    {data.users.map((u) => (
                      <option key={u} value={u}>{u}</option>
                    ))}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
