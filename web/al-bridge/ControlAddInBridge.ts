export type PickBoardMessage =
  | { type: "setData"; payload: unknown }
  | { type: "setLocale"; locale: string }
  | { type: "applyFilter"; filter: unknown }
  | { type: "notifyResult"; payload: unknown };

type Listener = (message: PickBoardMessage) => void;

const listeners = new Set<Listener>();

export function listenBridge(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function reassign(pickNo: string, userId: string) {
  const microsoft = (window as Window & { Microsoft?: { Dynamics?: { NAV?: { InvokeExtensibilityMethod?: (...args: unknown[]) => void } } } }).Microsoft;
  microsoft?.Dynamics?.NAV?.InvokeExtensibilityMethod?.("Reassign", [pickNo, userId]);
  window.parent?.postMessage({ type: "reassign", pickNo, userId }, "*");
}

export function requestRefresh() {
  const microsoft = (window as Window & { Microsoft?: { Dynamics?: { NAV?: { InvokeExtensibilityMethod?: (...args: unknown[]) => void } } } }).Microsoft;
  microsoft?.Dynamics?.NAV?.InvokeExtensibilityMethod?.("RequestRefresh", []);
  window.parent?.postMessage({ type: "requestRefresh" }, "*");
}

/** Ops Console: bir belgeyi (pick/putaway/shipment/count) bir kullanıcıya ata/yeniden ata. */
export function assignDoc(docType: string, docNo: string, userId: string) {
  const microsoft = (window as Window & { Microsoft?: { Dynamics?: { NAV?: { InvokeExtensibilityMethod?: (...args: unknown[]) => void } } } }).Microsoft;
  microsoft?.Dynamics?.NAV?.InvokeExtensibilityMethod?.("AssignDoc", [docType, docNo, userId]);
  window.parent?.postMessage({ type: "assignDoc", docType, docNo, userId }, "*");
}

/** Ops Console (ELOG multi): seçili siparişleri tek pick'te grupla ve kullanıcıya ata. */
export function createMultiPick(orderNosCsv: string, userId: string) {
  const microsoft = (window as Window & { Microsoft?: { Dynamics?: { NAV?: { InvokeExtensibilityMethod?: (...args: unknown[]) => void } } } }).Microsoft;
  microsoft?.Dynamics?.NAV?.InvokeExtensibilityMethod?.("CreateMultiPick", [orderNosCsv, userId]);
  window.parent?.postMessage({ type: "createMultiPick", orderNosCsv, userId }, "*");
}

window.addEventListener("message", (event) => {
  const data = event.data as PickBoardMessage;
  if (!data || typeof data !== "object" || !("type" in data)) return;
  if (data.type === "setData" || data.type === "setLocale" || data.type === "applyFilter") {
    listeners.forEach((listener) => listener(data));
  }
});

Object.assign(window, {
  SetData: (payload: unknown) => listeners.forEach((listener) => listener({ type: "setData", payload })),
  SetLocale: (locale: string) => listeners.forEach((listener) => listener({ type: "setLocale", locale })),
  ApplyFilter: (filter: unknown) => listeners.forEach((listener) => listener({ type: "applyFilter", filter })),
  NotifyResult: (payload: unknown) => {
    const parsed = typeof payload === "string" ? safeParse(payload) : payload;
    listeners.forEach((listener) => listener({ type: "notifyResult", payload: parsed }));
  },
});

function safeParse(raw: string): unknown {
  try { return JSON.parse(raw); } catch { return raw; }
}
