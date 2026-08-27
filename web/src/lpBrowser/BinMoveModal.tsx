import { useState } from "react";

type BinMoveModalProps = {
  lpNo: string;
  labels: {
    binCode: string;
    confirm: string;
    cancel: string;
  };
  onConfirm: (lpNo: string, binCode: string) => void;
  onCancel: () => void;
};

export function BinMoveModal({ lpNo, labels, onConfirm, onCancel }: BinMoveModalProps) {
  const [binCode, setBinCode] = useState("");
  return (
    <div className="lp-modal" role="dialog" aria-modal="true">
      <div className="lp-modal__panel">
        <h2>{lpNo}</h2>
        <label>
          {labels.binCode}
          <input value={binCode} onChange={(event) => setBinCode(event.target.value)} autoFocus />
        </label>
        <div className="lp-modal__actions">
          <button onClick={onCancel}>{labels.cancel}</button>
          <button onClick={() => onConfirm(lpNo, binCode)} disabled={!binCode.trim()}>{labels.confirm}</button>
        </div>
      </div>
    </div>
  );
}
