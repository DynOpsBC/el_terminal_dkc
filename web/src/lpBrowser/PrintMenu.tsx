type PrintMenuProps = {
  lpNo: string;
  x: number;
  y: number;
  labels: {
    printLabel: string;
    moveToBin: string;
    properties: string;
  };
  onPrint: (lpNo: string) => void;
  onMoveToBin: (lpNo: string) => void;
  onClose: () => void;
};

export function PrintMenu({ lpNo, x, y, labels, onPrint, onMoveToBin, onClose }: PrintMenuProps) {
  return (
    <div className="lp-menu" style={{ left: x, top: y }} role="menu" onMouseLeave={onClose}>
      <button role="menuitem" onClick={() => onPrint(lpNo)}>{labels.printLabel}</button>
      <button role="menuitem" onClick={() => onMoveToBin(lpNo)}>{labels.moveToBin}</button>
      <button role="menuitem" onClick={onClose}>{labels.properties}</button>
    </div>
  );
}
