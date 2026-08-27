// Ops Console veri modeli + BC'den gelen payload'ı normalize eden yardımcı.
// Toplantı isteği: "kararlar bilgisayardan verilsin" — süpervizör masaüstünden
// işleri atar/izler; el terminali yalnız fiziksel yürütmeyi yapar.

export type DocType = "pick" | "putaway" | "shipment" | "count";

export type OpsDoc = {
  no: string;
  sourceNo: string;
  assignedUserId: string;
  status: string;
  percent: number;
};

export type OpsSummary = {
  receipts: number;
  putaways: number;
  picks: number;
  shipments: number;
  counts: number;
  unassigned: number;
  inProgress: number;
};

// ELOG multi akışı: gruplanabilir satış siparişi (henüz sevkiyata bağlanmamış).
export type OpsOrder = {
  no: string;
  customer: string;
  location: string;
  lines: number;
  qty: number;
  status: string;
};

export type OpsData = {
  summary: OpsSummary;
  users: string[];
  docs: Record<DocType, OpsDoc[]>;
  orders: OpsOrder[];
};

export const EMPTY_SUMMARY: OpsSummary = {
  receipts: 0, putaways: 0, picks: 0, shipments: 0, counts: 0, unassigned: 0, inProgress: 0,
};

export const emptyOps = (): OpsData => ({
  summary: { ...EMPTY_SUMMARY },
  users: [],
  docs: { pick: [], putaway: [], shipment: [], count: [] },
  orders: [],
});

// Standalone geliştirme için örnek veri (BC bağlıyken SetData ile ezilir).
export const seedOps = (): OpsData => ({
  summary: { receipts: 4, putaways: 3, picks: 6, shipments: 2, counts: 1, unassigned: 3, inProgress: 5 },
  users: ["Ada Yılmaz", "Mert Demir", "Selin Kaya"],
  docs: {
    pick: [
      { no: "WP-000142", sourceNo: "SO-104233", assignedUserId: "Ada Yılmaz", status: "InProgress", percent: 72 },
      { no: "WP-000148", sourceNo: "TO-100120", assignedUserId: "", status: "Open", percent: 0 },
      { no: "WP-000149", sourceNo: "SO-104288", assignedUserId: "", status: "Open", percent: 0 },
    ],
    putaway: [
      { no: "WA-000051", sourceNo: "WR-004992", assignedUserId: "Mert Demir", status: "InProgress", percent: 30 },
      { no: "WA-000052", sourceNo: "WR-005001", assignedUserId: "", status: "Open", percent: 0 },
    ],
    shipment: [
      { no: "WS-000014", sourceNo: "SO-104260", assignedUserId: "Selin Kaya", status: "InProgress", percent: 50 },
    ],
    count: [
      { no: "CNT-0007", sourceNo: "WHITE", assignedUserId: "", status: "Open", percent: 0 },
    ],
  },
  orders: [
    { no: "SO-104301", customer: "Kontorland A/S", location: "WHITE", lines: 3, qty: 12, status: "Released" },
    { no: "SO-104302", customer: "Möbel-Meller KG", location: "WHITE", lines: 1, qty: 2, status: "Open" },
    { no: "SO-104305", customer: "Antarcticopy", location: "WHITE", lines: 2, qty: 6, status: "Released" },
  ],
});

function num(v: unknown): number {
  const n = typeof v === "number" ? v : parseFloat(String(v ?? ""));
  return Number.isFinite(n) ? n : 0;
}
function str(v: unknown): string {
  return v == null ? "" : String(v);
}
function docArray(v: unknown): OpsDoc[] {
  if (!Array.isArray(v)) return [];
  return v.map((d) => {
    const o = (d ?? {}) as Record<string, unknown>;
    return {
      no: str(o.no),
      sourceNo: str(o.sourceNo),
      assignedUserId: str(o.assignedUserId),
      status: str(o.status) || "Open",
      percent: num(o.percent ?? o.percentComplete),
    };
  });
}

function orderArray(v: unknown): OpsOrder[] {
  if (!Array.isArray(v)) return [];
  return v.map((d) => {
    const o = (d ?? {}) as Record<string, unknown>;
    return {
      no: str(o.no),
      customer: str(o.customer),
      location: str(o.location),
      lines: num(o.lines),
      qty: num(o.qty),
      status: str(o.status) || "Open",
    };
  });
}

export function normalizeOps(payload: unknown): OpsData {
  const p = (payload ?? {}) as Record<string, unknown>;
  const s = (p.summary ?? {}) as Record<string, unknown>;
  const d = (p.docs ?? {}) as Record<string, unknown>;
  return {
    summary: {
      receipts: num(s.receipts), putaways: num(s.putaways), picks: num(s.picks),
      shipments: num(s.shipments), counts: num(s.counts),
      unassigned: num(s.unassigned), inProgress: num(s.inProgress),
    },
    users: Array.isArray(p.users) ? (p.users as unknown[]).map(str).filter(Boolean) : [],
    docs: {
      pick: docArray(d.pick),
      putaway: docArray(d.putaway),
      shipment: docArray(d.shipment),
      count: docArray(d.count),
    },
    orders: orderArray(p.orders),
  };
}
