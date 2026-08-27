import { expect, test } from "@playwright/test";

// PickBoard is an AL ControlAddIn that consumes data via window.postMessage
// (BcDataBridge), not HTTP. So we drive it with two setData messages: the
// initial snapshot, then a follow-up to prove the update path works.
test("pick board renders bridge data and reflects setData updates", async ({ page }) => {
  await page.goto("/src/pickBoard/index.html");
  await expect(page.getByRole("heading", { name: "Pick Board" })).toBeVisible();

  await page.evaluate(() => {
    window.postMessage(
      {
        type: "setData",
        payload: {
          picks: [
            { no: "PICK-S5-0001", sourceNo: "SHIP-1001", assignedUserId: "MOBILE", status: "Open", percentComplete: 10 },
            { no: "PICK-S5-0002", sourceNo: "SHIP-1002", assignedUserId: "ADA", status: "InProgress", percentComplete: 60 },
          ],
        },
      },
      "*",
    );
  });
  await expect(page.getByText("PICK-S5-0001")).toBeVisible();
  await expect(page.getByText("PICK-S5-0002")).toBeVisible();

  await page.evaluate(() => {
    window.postMessage(
      {
        type: "setData",
        payload: {
          picks: [{ no: "PICK-S5-0099", sourceNo: "SHIP-1099", assignedUserId: "MOBILE", status: "Open", percentComplete: 0 }],
        },
      },
      "*",
    );
  });
  await expect(page.getByText("PICK-S5-0099")).toBeVisible();
});
