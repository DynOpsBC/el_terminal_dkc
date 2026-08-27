import { useCallback, useEffect, useState } from "react";
import { DndProvider } from "react-dnd";
import { HTML5Backend } from "react-dnd-html5-backend";
import { BinMoveModal } from "./BinMoveModal";
import { type LpNode, normalize, useBcLpData } from "./data/useBcLpData";
import { LpTreeNode } from "./LpTreeNode";
import { PrintMenu } from "./PrintMenu";
import en from "./i18n/en";
import tr from "./i18n/tr";
import de from "./i18n/de";

const dictionaries = { en, tr, de };

type MenuState = { lpNo: string; x: number; y: number } | null;

export function LpBrowserApp() {
  const { lps, setLps, loading, error, refresh } = useBcLpData();
  const [locale, setLocale] = useState<keyof typeof dictionaries>("en");
  const [menu, setMenu] = useState<MenuState>(null);
  const [moveLpNo, setMoveLpNo] = useState<string | null>(null);
  const labels = dictionaries[locale];

  useEffect(() => {
    Object.assign(window, {
      SetData: (payload: unknown) => setLps(normalizePayload(payload)),
      SetLocale: (code: string) => setLocale(code.startsWith("tr") ? "tr" : code.startsWith("de") ? "de" : "en"),
      RefreshTree: () => void refresh(),
    });
    const listener = (event: MessageEvent) => {
      const data = event.data as { type?: string; payload?: unknown; locale?: string };
      if (data.type === "setData") setLps(normalizePayload(data.payload));
      if (data.type === "setLocale" && data.locale) setLocale(data.locale.startsWith("tr") ? "tr" : data.locale.startsWith("de") ? "de" : "en");
    };
    window.addEventListener("message", listener);
    return () => window.removeEventListener("message", listener);
  }, [refresh, setLps]);

  const invoke = useCallback((name: string, args: unknown[]) => {
    const microsoft = (window as Window & { Microsoft?: { Dynamics?: { NAV?: { InvokeExtensibilityMethod?: (...args: unknown[]) => void } } } }).Microsoft;
    microsoft?.Dynamics?.NAV?.InvokeExtensibilityMethod?.(name, args);
    window.parent?.postMessage({ type: name, args }, "*");
  }, []);

  // Tell the BC host the add-in is mounted so it can push the live LP tree via SetData.
  useEffect(() => { invoke("ControlReady", []); }, [invoke]);

  const onNest = useCallback((childLpNo: string, parentLpNo: string) => {
    setLps((current) => moveNode(current, childLpNo, parentLpNo));
    invoke("NestLp", [childLpNo, parentLpNo]);
  }, [invoke, setLps]);

  const onLoadChildren = useCallback(async (lpNo: string): Promise<LpNode[]> => {
    const response = await fetch(`/api/dynops/advWms/v2.0/licensePlates?$filter=parentLpNo eq '${encodeURIComponent(lpNo)}'`);
    if (!response.ok) return [];
    const payload = await response.json() as { value?: unknown[] };
    return normalizePayload(payload.value ?? []);
  }, []);

  return (
    <DndProvider backend={HTML5Backend}>
      <main className="lp-browser">
        <header className="lp-browser__header">
          <h1>{labels.title}</h1>
          <button onClick={() => void refresh()}>{labels.refresh}</button>
        </header>
        {loading ? <p>{labels.loading}</p> : null}
        {error ? <p className="lp-browser__error">{error}</p> : null}
        {!loading && lps.length === 0 ? <p>{labels.empty}</p> : null}
        <ul className="lp-tree">
          {lps.map((lp) => (
            <LpTreeNode
              key={lp.no}
              node={lp}
              onNest={onNest}
              onContextMenu={(lpNo, x, y) => setMenu({ lpNo, x, y })}
              onLoadChildren={onLoadChildren}
            />
          ))}
        </ul>
        {menu ? (
          <PrintMenu
            lpNo={menu.lpNo}
            x={menu.x}
            y={menu.y}
            labels={labels}
            onPrint={(lpNo) => invoke("PrintLabel", [lpNo, ""])}
            onMoveToBin={(lpNo) => {
              setMoveLpNo(lpNo);
              setMenu(null);
            }}
            onClose={() => setMenu(null)}
          />
        ) : null}
        {moveLpNo ? (
          <BinMoveModal
            lpNo={moveLpNo}
            labels={labels}
            onCancel={() => setMoveLpNo(null)}
            onConfirm={(lpNo, binCode) => {
              invoke("MoveLpToBin", [lpNo, binCode]);
              setMoveLpNo(null);
            }}
          />
        ) : null}
      </main>
    </DndProvider>
  );
}

function normalizePayload(payload: unknown): LpNode[] {
  if (typeof payload === "string") {
    try {
      return normalizePayload(JSON.parse(payload));
    } catch {
      return [];
    }
  }
  const candidate = payload as { lps?: unknown[]; value?: unknown[] } | unknown[] | undefined;
  const items = Array.isArray(candidate) ? candidate : candidate?.lps ?? candidate?.value ?? [];
  return normalize(items as Parameters<typeof normalize>[0]);
}

function moveNode(nodes: LpNode[], childLpNo: string, parentLpNo: string): LpNode[] {
  let moving: LpNode | undefined;
  const remove = (items: LpNode[]): LpNode[] => items.flatMap((node) => {
    if (node.no === childLpNo) {
      moving = { ...node, parentLpNo };
      return [];
    }
    return [{ ...node, children: remove(node.children ?? []) }];
  });
  const add = (items: LpNode[]): LpNode[] => items.map((node) => {
    if (node.no === parentLpNo && moving) return { ...node, children: [...(node.children ?? []), moving] };
    return { ...node, children: add(node.children ?? []) };
  });
  return add(remove(nodes));
}
