import { useEffect, useState } from "react";
import { requestRefresh } from "../../../al-bridge/ControlAddInBridge";

export type Pick = {
  no: string;
  sourceNo: string;
  assignedUserId: string;
  status: "Open" | "InProgress" | "Done" | string;
  percentComplete: number;
  dueDate?: string;
};

export type PickBoardData = { picks: Pick[]; users: string[] };

const seed: Pick[] = [
  { no: "WP-000142", sourceNo: "SO-104233", assignedUserId: "Ada Yılmaz", status: "InProgress", percentComplete: 72, dueDate: "2026-05-28" },
  { no: "WP-000143", sourceNo: "SO-104251", assignedUserId: "Ada Yılmaz", status: "Open", percentComplete: 0, dueDate: "2026-05-28" },
  { no: "WP-000144", sourceNo: "TO-100118", assignedUserId: "Mert Demir", status: "InProgress", percentComplete: 40, dueDate: "2026-05-28" },
  { no: "WP-000145", sourceNo: "SO-104260", assignedUserId: "Mert Demir", status: "Open", percentComplete: 15, dueDate: "2026-05-29" },
  { no: "WP-000146", sourceNo: "SO-104261", assignedUserId: "Mert Demir", status: "Done", percentComplete: 100, dueDate: "2026-05-27" },
  { no: "WP-000147", sourceNo: "SO-104270", assignedUserId: "Selin Kaya", status: "InProgress", percentComplete: 88, dueDate: "2026-05-28" },
  { no: "WP-000148", sourceNo: "TO-100120", assignedUserId: "", status: "Open", percentComplete: 0, dueDate: "2026-05-29" },
  { no: "WP-000149", sourceNo: "SO-104288", assignedUserId: "", status: "Open", percentComplete: 0, dueDate: "2026-05-30" },
];

export function useBcData(initialData?: PickBoardData) {
  const [data, setData] = useState<PickBoardData>(initialData ?? {
    picks: seed,
    users: [...new Set(seed.map((pick) => pick.assignedUserId).filter(Boolean))],
  });

  useEffect(() => {
    const load = async () => {
      try {
        const response = await fetch("/picks?$filter=status eq 'Open' or status eq 'InProgress'");
        if (response.ok) {
          const json = await response.json();
          const picks = json.value ?? json.picks ?? seed;
          setData({
            picks,
            users: Array.isArray(json.users)
              ? json.users.filter((user: unknown): user is string => typeof user === "string" && user.trim().length > 0)
              : [...new Set(picks.map((pick: Pick) => pick.assignedUserId).filter(Boolean))],
          });
        } else {
          requestRefresh();
        }
      } catch {
        requestRefresh();
      }
    };
    const id = window.setInterval(load, 5000);
    return () => window.clearInterval(id);
  }, []);

  return { data, setData };
}
