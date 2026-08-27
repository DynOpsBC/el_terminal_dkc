/// <reference types="vitest" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// `BCWMS_TARGET=al` (default) → AL ControlAddIn bundle (no SW).
// `BCWMS_TARGET=saas` → standalone SaaS bundle for Static Web App with PWA SW.
const target = process.env.BCWMS_TARGET ?? "al";
const isSaas = target === "saas";

export default defineConfig({
  resolve: isSaas
    ? undefined
    : {
        alias: {
          "virtual:pwa-register": new URL("./src/lib/pwa-register-stub.ts", import.meta.url).pathname,
        },
      },
  plugins: [
    react(),
    ...(isSaas
      ? [
          VitePWA({
            registerType: "prompt",
            includeAssets: ["favicon.svg"],
            manifest: {
              name: "BCWMS Workstation",
              short_name: "BCWMS",
              theme_color: "#6c5ce7",
              background_color: "#faf8f3",
              display: "standalone",
              icons: [],
            },
            workbox: {
              globPatterns: ["**/*.{js,css,html,svg,woff2}"],
              navigateFallback: "index.html",
              cleanupOutdatedCaches: true,
            },
          }),
        ]
      : []),
  ],
  // tests/ klasörü Playwright spec'leri içerir, vitest tarafından
  // çalıştırılamaz. Vitest sadece src/ altındaki *.test.ts(x) dosyalarını alır.
  test: {
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    exclude: ["node_modules/**", "tests/**", "dist/**"],
    passWithNoTests: true,
  },
  build: isSaas
    ? {
        outDir: "dist",
        emptyOutDir: true,
        sourcemap: true,
      }
    : {
        outDir: "../al/src/ControlAddIn/Resources/",
        emptyOutDir: true,
        sourcemap: true,
        rollupOptions: {
          input: {
            main: "index.html",
            pickBoard: "src/pickBoard/index.html",
            lpBrowser: "src/lpBrowser/index.html",
            opsConsole: "src/opsConsole/index.html",
          },
          output: {
            entryFileNames: (chunk) =>
              chunk.name === "pickBoard" ? "pickBoard.js"
                : chunk.name === "lpBrowser" ? "lpBrowser.js"
                : chunk.name === "opsConsole" ? "opsConsole.js"
                : "assets/[name].js",
            assetFileNames: (asset) => {
              if (asset.name?.includes("lpBrowser") && asset.name.endsWith(".css")) return "lpBrowser.css";
              if (asset.name?.includes("opsConsole") && asset.name.endsWith(".css")) return "opsConsole.css";
              if (asset.name?.endsWith(".css")) return "pickBoard.css";
              return "assets/[name][extname]";
            },
          },
        },
      },
});
