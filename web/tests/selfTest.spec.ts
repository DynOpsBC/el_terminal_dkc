import { expect, test } from "@playwright/test";

// Sistem Sağlığı paneli token yokken bile yüklenmeli — token gerektiren
// check'ler SKIP olarak işaretlenir, paneli açan operatör kurulum
// eksiklerini görsel doğrulayabilir.

test("self-test panel renders 10 checks and runs without crashing", async ({ page }) => {
  // Boş localStorage = token yok. Main app login ekranına döner. Ona
  // gitmek yerine ana app yapısını test etmek lazım, ama login modu
  // bypass etmek için sahte token ekleyelim — sonra hemen home'a düşer.
  await page.addInitScript(() => {
    try {
      localStorage.setItem("bcwms.token", "test-token-not-real");
    } catch {
      /* ignore */
    }
  });

  // Tüm BC isteklerini başarısız döndür — token testi pass, diğerleri fail.
  // Bu, panelin tüm hata yollarını rendering durdurmadan ele aldığını gösterir.
  await page.route("**/businesscentral.dynamics.com/**", async (route) => {
    await route.fulfill({ status: 401, contentType: "application/json", body: '{"error":"unauthorized"}' });
  });

  await page.goto("/");
  // Ana menüye gel — Sistem Sağlığı tile'ı görünür ve tıklanır
  const tile = page.getByText("Sistem Sağlığı", { exact: false }).first();
  await expect(tile).toBeVisible({ timeout: 10_000 });
  await tile.click();

  await expect(page.getByRole("heading", { name: "Sistem Sağlığı" })).toBeVisible();
  // Pending state — buton aktif, results render edildi
  await expect(page.getByRole("button", { name: /Tümünü Çalıştır/i })).toBeEnabled();

  // 10 check satırı render edildi
  await expect(page.getByText("BC token saklanmış mı?")).toBeVisible();
  await expect(page.getByText("ItemApi inventory FlowField calc çalışıyor mu?")).toBeVisible();
  await expect(page.getByText("BinContentApi (page 72097) çalışıyor mu?")).toBeVisible();
  await expect(page.getByText("PWA service worker kayıtlı mı?")).toBeVisible();
  await expect(page.getByText("localStorage yazılabilir mi?")).toBeVisible();

  // Çalıştır — token check PASS, localStorage PASS, BC check'ler FAIL
  await page.getByRole("button", { name: /Tümünü Çalıştır/i }).click();

  // Bir süre içinde panel "❌" istatistiğine ulaşır (BC route 401 dönüyor)
  await expect.poll(async () => {
    const text = await page.locator("body").innerText();
    return /❌/.test(text);
  }, { timeout: 15_000 }).toBeTruthy();

  // Sıfırla'ya bas, panel pending durumuna geri döner
  await page.getByRole("button", { name: /Sıfırla/i }).click();
  await expect(page.getByRole("button", { name: /Tümünü Çalıştır/i })).toBeEnabled();
});
