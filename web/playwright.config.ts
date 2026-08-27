import { defineConfig, devices } from "@playwright/test";

// Test'ler index.html ve src/<X>/index.html dosyalarına vite dev server
// üzerinden ulaşır. Playwright kendi server'ını başlatır, port 5179 →
// vite default 5173 ile çakışmasın.
const PORT = Number(process.env.PLAYWRIGHT_PORT ?? 5179);

export default defineConfig({
  testDir: "tests",
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: `pnpm exec vite --port ${PORT} --strictPort`,
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
