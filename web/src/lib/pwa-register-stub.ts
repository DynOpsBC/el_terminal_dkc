// Build-time stub for `virtual:pwa-register` when the PWA plugin isn't
// loaded (AL ControlAddIn target). registerSW returns a noop updater so the
// dynamic import resolves cleanly without bundling the workbox runtime.

export function registerSW(_options?: unknown): (reloadPage?: boolean) => Promise<void> {
  return async (_reloadPage?: boolean) => undefined;
}
