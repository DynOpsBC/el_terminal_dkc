import { useDrag, useDrop } from "react-dnd";

export const LP_NODE_TYPE = "DOPSWHS_LP_NODE";

export type DragLpItem = {
  type: typeof LP_NODE_TYPE;
  lpNo: string;
};

export function useLpDrag(lpNo: string) {
  return useDrag(() => ({
    type: LP_NODE_TYPE,
    item: { type: LP_NODE_TYPE, lpNo },
    collect: (monitor) => ({ isDragging: monitor.isDragging() }),
  }), [lpNo]);
}

export function useLpDrop(parentLpNo: string, onNest: (childLpNo: string, parentLpNo: string) => void) {
  return useDrop<DragLpItem, void, { isOver: boolean }>(() => ({
    accept: LP_NODE_TYPE,
    drop: (item) => {
      if (item.lpNo !== parentLpNo) onNest(item.lpNo, parentLpNo);
    },
    collect: (monitor) => ({ isOver: monitor.isOver({ shallow: true }) }),
  }), [parentLpNo, onNest]);
}
