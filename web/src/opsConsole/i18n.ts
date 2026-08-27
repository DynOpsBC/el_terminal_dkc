// Ops Console — minimal çoklu dil (BC GlobalLanguage → SetLocale ile seçilir).
export type OpsDict = {
  title: string;
  refresh: string;
  tabs: { pick: string; putaway: string; shipment: string; count: string; orders: string };
  tiles: { receipts: string; putaways: string; picks: string; shipments: string; counts: string; unassigned: string; inProgress: string };
  col: { no: string; source: string; status: string; progress: string; assignee: string; assign: string };
  ord: { customer: string; location: string; lines: string; qty: string; selected: string; createPick: string; assignTo: string; created: string };
  unassigned: string;
  empty: string;
};

const en: OpsDict = {
  title: "Ops Console",
  refresh: "Refresh",
  tabs: { pick: "Picks", putaway: "Put-Away", shipment: "Shipments", count: "Counts", orders: "Orders" },
  tiles: { receipts: "Receipts", putaways: "Put-Away", picks: "Picks", shipments: "Shipments", counts: "Counts", unassigned: "Unassigned", inProgress: "In Progress" },
  col: { no: "No.", source: "Source", status: "Status", progress: "Progress", assignee: "Assignee", assign: "Assign" },
  ord: { customer: "Customer", location: "Location", lines: "Lines", qty: "Qty", selected: "selected", createPick: "Create Pick & Assign", assignTo: "Assign to", created: "Pick created" },
  unassigned: "(unassigned)",
  empty: "No documents.",
};

const tr: OpsDict = {
  title: "Operasyon Konsolu",
  refresh: "Yenile",
  tabs: { pick: "Toplama", putaway: "Yerleştirme", shipment: "Sevkiyat", count: "Sayım", orders: "Siparişler" },
  tiles: { receipts: "Mal Kabul", putaways: "Yerleştirme", picks: "Toplama", shipments: "Sevkiyat", counts: "Sayım", unassigned: "Atanmamış", inProgress: "Devam Eden" },
  col: { no: "No", source: "Kaynak", status: "Durum", progress: "İlerleme", assignee: "Atanan", assign: "Ata" },
  ord: { customer: "Müşteri", location: "Lokasyon", lines: "Satır", qty: "Miktar", selected: "seçili", createPick: "Pick Oluştur & Ata", assignTo: "Atanacak kişi", created: "Pick oluşturuldu" },
  unassigned: "(boşta)",
  empty: "Belge yok.",
};

const de: OpsDict = {
  title: "Ops-Konsole",
  refresh: "Aktualisieren",
  tabs: { pick: "Kommissionierung", putaway: "Einlagerung", shipment: "Versand", count: "Zählung", orders: "Aufträge" },
  tiles: { receipts: "Wareneingang", putaways: "Einlagerung", picks: "Kommiss.", shipments: "Versand", counts: "Zählung", unassigned: "Nicht zugewiesen", inProgress: "In Arbeit" },
  col: { no: "Nr.", source: "Quelle", status: "Status", progress: "Fortschritt", assignee: "Zugewiesen", assign: "Zuweisen" },
  ord: { customer: "Kunde", location: "Lagerort", lines: "Zeilen", qty: "Menge", selected: "ausgewählt", createPick: "Kommiss. erstellen & zuweisen", assignTo: "Zuweisen an", created: "Kommissionierung erstellt" },
  unassigned: "(frei)",
  empty: "Keine Belege.",
};

export const dictionaries: Record<string, OpsDict> = { en, tr, de };

export function pickDict(locale: string): OpsDict {
  if (locale.startsWith("tr")) return tr;
  if (locale.startsWith("de")) return de;
  return en;
}
