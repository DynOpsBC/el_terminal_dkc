import { useDrag } from "react-dnd";
import type { Pick } from "./data/useBcData";

const STATUS_LABEL: Record<string, string> = { Open: "Açık", InProgress: "Devam", Done: "Bitti" };

export function PickCardDraggable({ pick }: { pick: Pick }) {
  const [{ isDragging }, drag] = useDrag(() => ({
    type: "pick",
    item: { pickNo: pick.no },
    collect: (monitor) => ({ isDragging: monitor.isDragging() }),
  }), [pick.no]);

  const statusKey = pick.status.toLowerCase();
  const src = pick.sourceNo.startsWith("TO") ? "Transfer" : "Satış";

  return (
    <article
      ref={(node) => { drag(node); }}
      className={`pick-card pick-card--${statusKey}`}
      style={{ opacity: isDragging ? 0.4 : 1 }}
    >
      <div className="pick-card__top">
        <strong>{pick.no}</strong>
        <span className={`pick-pill pick-pill--${statusKey}`}>{STATUS_LABEL[pick.status] ?? pick.status}</span>
      </div>
      <div className="pick-card__source"><span className="pick-card__srctag">{src}</span> {pick.sourceNo}</div>
      <div className="pick-card__progress" title={`%${pick.percentComplete}`}>
        <span style={{ width: `${pick.percentComplete}%` }} />
      </div>
      <div className="pick-card__foot">
        <span className="pick-card__pct">%{pick.percentComplete}</span>
        <span className="pick-card__due">⏱ {pick.dueDate ?? ""}</span>
      </div>
    </article>
  );
}
