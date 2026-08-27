import { useCallback, useEffect, useMemo, useState } from "react";

export type LpNode = {
  no: string;
  parentLpNo?: string;
  binCode?: string;
  status?: string;
  children?: LpNode[];
};

type ApiLp = {
  no?: string;
  parentLpNo?: string;
  binCode?: string;
  status?: string;
  lines?: ApiLp[];
  children?: ApiLp[];
};

// Nested demo tree shown standalone (when the BC API isn't reachable, e.g. dev preview).
const seed: LpNode[] = [
  {
    no: "LP000003", binCode: "SHIP-01", status: "Built",
    children: [
      {
        no: "LP000231", binCode: "SHIP-01", status: "Built",
        children: [
          { no: "LP000901", binCode: "SHIP-01", status: "Built" },
          { no: "LP000902", binCode: "SHIP-01", status: "Built" },
        ],
      },
      { no: "LP000232", binCode: "SHIP-01", status: "Built" },
    ],
  },
  {
    no: "LP000005", binCode: "BULK-01", status: "Built",
    children: [
      { no: "LP000240", binCode: "BULK-01", status: "Built" },
      { no: "LP000241", binCode: "BULK-01", status: "Open" },
    ],
  },
  { no: "LP000051", binCode: "PICK-01", status: "Open" },
  { no: "LP000052", binCode: "S-1-01", status: "Built" },
];

export function useBcLpData() {
  const [lps, setLps] = useState<LpNode[]>(seed);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch("/api/dynops/warehouse/v2.0/licensePlates?$expand=lines");
      if (!response.ok) throw new Error(`LP fetch failed: ${response.status}`);
      const payload = await response.json() as { value?: ApiLp[] } | ApiLp[];
      const nodes = normalize(Array.isArray(payload) ? payload : payload.value ?? []);
      setLps(nodes.length ? nodes : seed);
    } catch {
      // Standalone/dev preview: keep the demo tree instead of an empty browser.
      setLps(seed);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return useMemo(() => ({ lps, setLps, loading, error, refresh }), [lps, loading, error, refresh]);
}

export function normalize(items: ApiLp[]): LpNode[] {
  const map = new Map<string, LpNode>();
  items.forEach((item) => {
    if (!item.no) return;
    map.set(item.no, {
      no: item.no,
      parentLpNo: item.parentLpNo,
      binCode: item.binCode,
      status: item.status,
      children: normalize(item.children ?? item.lines ?? []),
    });
  });
  map.forEach((node) => {
    if (!node.parentLpNo) return;
    const parent = map.get(node.parentLpNo);
    if (parent) {
      parent.children = [...(parent.children ?? []), node];
    }
  });
  return [...map.values()].filter((node) => !node.parentLpNo || !map.has(node.parentLpNo));
}
