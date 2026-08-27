import React from "react";
import { subscribeUpdate } from "../lib/updateNotifier";

export function UpdateToast() {
  const [state, setState] = React.useState<{ needRefresh: boolean; apply: () => Promise<void> } | null>(null);
  const [busy, setBusy] = React.useState(false);

  React.useEffect(() => subscribeUpdate(setState), []);

  if (!state?.needRefresh) return null;

  return (
    <div className="update-toast" role="status" aria-live="polite">
      <div>
        <div style={{ fontFamily: "Fraunces, Georgia, serif", fontSize: 15, fontWeight: 600 }}>
          Yeni sürüm hazır
        </div>
        <div style={{ fontSize: 12, color: "hsl(var(--muted-foreground))", marginTop: 2 }}>
          Tarayıcıyı yenilemek için "Yenile"ye dokunun.
        </div>
      </div>
      <button
        className="primary"
        disabled={busy}
        onClick={async () => {
          setBusy(true);
          try { await state.apply(); } finally { setBusy(false); }
        }}
      >
        {busy ? "..." : "Yenile"}
      </button>
    </div>
  );
}
