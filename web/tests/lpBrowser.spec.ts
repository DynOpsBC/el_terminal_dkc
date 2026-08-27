import { expect, test } from "@playwright/test";

test("LP Browser renders tree, emits NestLp, and shows print menu", async ({ page }) => {
  await page.route("**/licensePlates?**", async (route) => {
    await route.fulfill({
      contentType: "application/json",
      body: JSON.stringify({
        value: [
          { no: "LP-ROOT-1", binCode: "A-01", status: "Open", children: [{ no: "LP-CHILD-1", parentLpNo: "LP-ROOT-1", binCode: "A-02", status: "Open" }] },
          { no: "LP-ROOT-2", binCode: "B-01", status: "Open" },
        ],
      }),
    });
  });

  await page.goto("/src/lpBrowser/index.html");
  await expect(page.getByRole("heading", { name: "LP Browser" })).toBeVisible();
  await expect(page.getByText("LP-ROOT-1")).toBeVisible();
  await expect(page.getByText("LP-CHILD-1")).toBeVisible();

  const events: unknown[] = [];
  await page.exposeFunction("captureLpEvent", (event: unknown) => events.push(event));
  await page.evaluate(() => {
    window.addEventListener("message", (event) => {
      if (event.data?.type === "NestLp") {
        void (window as unknown as { captureLpEvent: (event: unknown) => Promise<void> }).captureLpEvent(event.data);
      }
    });
  });

  await page.locator(".lp-node", { hasText: "LP-CHILD-1" }).dragTo(page.locator(".lp-node", { hasText: "LP-ROOT-2" }));
  await expect.poll(() => events.length).toBeGreaterThan(0);

  await page.locator(".lp-node", { hasText: "LP-ROOT-1" }).click({ button: "right" });
  await expect(page.getByRole("menuitem", { name: "Print Label" })).toBeVisible();
});
