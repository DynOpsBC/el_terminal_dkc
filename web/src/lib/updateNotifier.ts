/**
 * Service Worker update bridge. Only active when the SaaS bundle is built
 * (BCWMS_TARGET=saas) — virtual:pwa-register/react ships with the
 * vite-plugin-pwa plugin and noop's otherwise.
 *
 * Exposes a `subscribeUpdate(cb)` hook so React can render a toast and
 * trigger `apply()` to call `skipWaiting()` on the new SW.
 */

type UpdateCallback = (state: { needRefresh: boolean; apply: () => Promise<void> }) => void;

let cachedRegister: (() => Promise<void>) | null = null;
let pendingNeedRefresh = false;
let pendingApply: () => Promise<void> = async () => undefined;
const listeners = new Set<UpdateCallback>();

function emit(): void {
  for (const cb of listeners) cb({ needRefresh: pendingNeedRefresh, apply: pendingApply });
}

export function subscribeUpdate(cb: UpdateCallback): () => void {
  listeners.add(cb);
  cb({ needRefresh: pendingNeedRefresh, apply: pendingApply });
  return () => {
    listeners.delete(cb);
  };
}

export async function initServiceWorker(): Promise<void> {
  if (typeof window === "undefined") return;
  if (cachedRegister) {
    await cachedRegister();
    return;
  }
  try {
    // Dynamic import keeps this opt-in: when the SaaS plugin isn't present
    // the virtual module 404s and we silently skip SW.
    const mod = (await import(/* @vite-ignore */ "virtual:pwa-register")) as {
      registerSW: (options: {
        onNeedRefresh?: () => void;
        onOfflineReady?: () => void;
      }) => (reloadPage?: boolean) => Promise<void>;
    };
    const updateSW = mod.registerSW({
      onNeedRefresh: () => {
        pendingNeedRefresh = true;
        pendingApply = async () => {
          await updateSW(true);
        };
        emit();
      },
      onOfflineReady: () => undefined,
    });
    cachedRegister = async () => undefined;
  } catch {
    // No SW build (BCWMS_TARGET=al) — silently noop.
  }
}
