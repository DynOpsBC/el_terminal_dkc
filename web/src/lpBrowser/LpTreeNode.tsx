import { useCallback, useState } from "react";
import { type LpNode } from "./data/useBcLpData";
import { useLpDrag, useLpDrop } from "./DragNestHandler";

type LpTreeNodeProps = {
  node: LpNode;
  depth?: number;
  onNest: (childLpNo: string, parentLpNo: string) => void;
  onContextMenu: (lpNo: string, x: number, y: number) => void;
  onLoadChildren: (lpNo: string) => Promise<LpNode[]>;
};

export function LpTreeNode({ node, depth = 0, onNest, onContextMenu, onLoadChildren }: LpTreeNodeProps) {
  const [expanded, setExpanded] = useState(depth === 0);
  const [children, setChildren] = useState<LpNode[]>(node.children ?? []);
  const [{ isDragging }, dragRef] = useLpDrag(node.no);
  const [{ isOver }, dropRef] = useLpDrop(node.no, onNest);
  const hasChildren = children.length > 0;
  const icon = depth === 0 ? "🟫" : depth === 1 ? "📦" : "🔖";
  const kind = depth === 0 ? "Palet" : depth === 1 ? "Koli" : "Birim";
  const statusKey = (node.status ?? "").toLowerCase();

  const toggle = useCallback(async () => {
    if (!expanded && children.length === 0) {
      setChildren(await onLoadChildren(node.no));
    }
    setExpanded((value) => !value);
  }, [children.length, expanded, node.no, onLoadChildren]);

  return (
    <li>
      <div
        ref={(element) => {
          dragRef(element);
          dropRef(element);
        }}
        className={`lp-node lp-node--d${Math.min(depth, 2)}${isOver ? " lp-node--over" : ""}${isDragging ? " lp-node--dragging" : ""}`}
        onContextMenu={(event) => {
          event.preventDefault();
          onContextMenu(node.no, event.clientX, event.clientY);
        }}
      >
        <button className="lp-node__toggle" onClick={toggle} aria-label={expanded ? "Collapse" : "Expand"}>
          {hasChildren ? (expanded ? "▾" : "▸") : ""}
        </button>
        <span className="lp-node__icon" aria-hidden="true">{icon}</span>
        <span className="lp-node__no">{node.no}<span className="lp-node__kind">{kind}</span></span>
        {node.binCode ? <span className="lp-node__bin">📍 {node.binCode}</span> : <span />}
        {hasChildren ? <span className="lp-node__count">{children.length}</span> : <span />}
        <span className={`lp-badge lp-badge--${statusKey || "none"}`}>{node.status ?? "—"}</span>
        <span className="lp-node__handle" aria-hidden="true" title="Sürükle">⋮⋮</span>
      </div>
      {expanded && hasChildren ? (
        <ul className="lp-tree">
          {children.map((child) => (
            <LpTreeNode
              key={child.no}
              node={child}
              depth={depth + 1}
              onNest={onNest}
              onContextMenu={onContextMenu}
              onLoadChildren={onLoadChildren}
            />
          ))}
        </ul>
      ) : null}
    </li>
  );
}
