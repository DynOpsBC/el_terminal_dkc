import { useCallback, useEffect, useMemo, useState } from "react";
import { DndProvider } from "react-dnd";
import { HTML5Backend } from "react-dnd-html5-backend";
import { listenBridge } from "../../al-bridge/ControlAddInBridge";
import { reassignPick } from "./ReassignMutation";
import { PickerColumn } from "./PickerColumn";
import { type PickBoardData, useBcData } from "./data/useBcData";
import en from "./i18n/en";
import tr from "./i18n/tr";
import de from "./i18n/de";
import "./styles.css";

const dictionaries = { en, tr, de };

export function PickBoardApp() {
  const { data, setData } = useBcData();
  const [locale, setLocale] = useState<keyof typeof dictionaries>("en");

  useEffect(() => {
    const unsubscribe = listenBridge((message) => {
      if (message.type === "setData") setData(normalizeData(message.payload));
      if (message.type === "setLocale") setLocale(message.locale.startsWith("tr") ? "tr" : message.locale.startsWith("de") ? "de" : "en");
    });
    return () => { unsubscribe(); };
  }, [setData]);

  const byPicker = useMemo(() => {
    const map = new Map<string, typeof data.picks>();
    map.set("", []);
    data.users.forEach((userId) => map.set(userId, []));
    data.picks.forEach((pick) => {
      const key = pick.assignedUserId || "";
      map.set(key, [...(map.get(key) ?? []), pick]);
    });
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [data.picks, data.users]);

  const onReassign = useCallback((pickNo: string, userId: string) => {
    setData((current) => ({
      users: current.users,
      picks: current.picks.map((pick) => pick.no === pickNo ? { ...pick, assignedUserId: userId, status: "InProgress" } : pick),
    }));
    reassignPick(pickNo, userId);
  }, [setData]);

  const t = dictionaries[locale];

  const stats = useMemo(() => {
    const total = data.picks.length;
    const open = data.picks.filter((p) => p.status === "Open").length;
    const inProgress = data.picks.filter((p) => p.status === "InProgress").length;
    const done = data.picks.filter((p) => p.status === "Done").length;
    const avg = total ? Math.round(data.picks.reduce((s, p) => s + (p.percentComplete || 0), 0) / total) : 0;
    return { total, open, inProgress, done, avg };
  }, [data.picks]);

  return (
    <DndProvider backend={HTML5Backend}>
      <main className="pick-board">
        <header className="pick-board__header">
          <div className="pick-board__title">
            <span className="pick-board__brand">DynOps WMS</span>
            <h1>{t.title}</h1>
          </div>
          <div className="pick-board__stats">
            <div className="stat"><span className="stat__value">{stats.total}</span><span className="stat__label">Toplam</span></div>
            <div className="stat stat--open"><span className="stat__value">{stats.open}</span><span className="stat__label">Açık</span></div>
            <div className="stat stat--prog"><span className="stat__value">{stats.inProgress}</span><span className="stat__label">Devam</span></div>
            <div className="stat stat--done"><span className="stat__value">{stats.done}</span><span className="stat__label">Bitti</span></div>
            <div className="stat stat--avg"><span className="stat__value">%{stats.avg}</span><span className="stat__label">Ortalama</span></div>
          </div>
        </header>
        {data.picks.length === 0 ? <p className="pick-board__empty">{t.empty}</p> : (
          <div className="pick-board__columns">
            {byPicker.map(([userId, picks]) => (
              <PickerColumn key={userId || "unassigned"} userId={userId} picks={picks} onReassign={onReassign} />
            ))}
          </div>
        )}
      </main>
    </DndProvider>
  );
}

function normalizeData(payload: unknown): PickBoardData {
  if (typeof payload === "string") {
    try {
      return normalizeData(JSON.parse(payload));
    } catch {
      return { picks: [], users: [] };
    }
  }
  const candidate = payload as Partial<PickBoardData> | undefined;
  return {
    picks: Array.isArray(candidate?.picks) ? candidate.picks : [],
    users: Array.isArray(candidate?.users)
      ? candidate.users.filter((user): user is string => typeof user === "string" && user.trim().length > 0)
      : [],
  };
}
