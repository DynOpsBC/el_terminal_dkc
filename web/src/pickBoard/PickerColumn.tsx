import { useDrop } from "react-dnd";
import { PickCardDraggable } from "./PickCardDraggable";
import type { Pick } from "./data/useBcData";

const PALETTE = ["#6366f1", "#0ea5e9", "#14b8a6", "#f59e0b", "#ec4899", "#8b5cf6"];

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function colorFor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return PALETTE[h % PALETTE.length];
}

export function PickerColumn({ userId, picks, onReassign }: { userId: string; picks: Pick[]; onReassign: (pickNo: string, userId: string) => void }) {
  const [{ isOver }, drop] = useDrop(() => ({
    accept: "pick",
    drop: (item: { pickNo: string }) => onReassign(item.pickNo, userId),
    collect: (monitor) => ({ isOver: monitor.isOver() }),
  }), [userId, onReassign]);

  const name = userId || "Atanmamış";
  const unassigned = !userId;

  return (
    <section ref={(node) => { drop(node); }} className={`picker-column ${isOver ? "picker-column--over" : ""} ${unassigned ? "picker-column--unassigned" : ""}`}>
      <header>
        <div className="picker-column__who">
          <span className="avatar" style={{ background: unassigned ? "#94a3b8" : colorFor(name) }}>{unassigned ? "★" : initials(name)}</span>
          <h2>{name}</h2>
        </div>
        <span className="picker-column__count">{picks.length}</span>
      </header>
      <div className="picker-column__cards">
        {picks.map((pick) => <PickCardDraggable key={pick.no} pick={pick} />)}
        {picks.length === 0 ? <div className="picker-column__drop">Buraya sürükleyin</div> : null}
      </div>
    </section>
  );
}
