import { expect, test } from "@playwright/test";
import {
  completeTaskerOnboarding,
  signUpAndLogin,
  testProxy,
} from "../../Patchwork_MCP/tests/ui/helpers/auth";

const whitehorse = {
  city: "Whitehorse",
  province: "YT",
  lat: 60.7212,
  lng: -135.0568,
};

test.describe("Tasker subscription visibility", () => {
  test.describe.configure({ timeout: 240000 });

  test.beforeAll(async () => {
    await testProxy("ensureCategoryExists", { name: "Cleaning" });
  });

  test("taskers who skip subscription stay hidden from seeker discovery", async ({ browser }) => {
    const taskerEmail = `skip_hidden_${Date.now()}@test.com`;
    const seekerEmail = `skip_hidden_seeker_${Date.now()}@test.com`;
    const taskerName = "Skip Hidden Services";

    const taskerContext = await browser.newContext();
    const taskerPage = await taskerContext.newPage();
    const seekerContext = await browser.newContext();
    const seekerPage = await seekerContext.newPage();

    try {
      await signUpAndLogin(taskerPage, taskerEmail, "Skip", "Tasker", whitehorse.city, whitehorse.province);
      await completeTaskerOnboarding(taskerPage, {
        category: "Cleaning",
        displayName: taskerName,
        hourlyRate: "70",
        plan: "skip",
      });

      await testProxy("setTaskerLocationByEmail", {
        email: taskerEmail,
        lat: whitehorse.lat,
        lng: whitehorse.lng,
      });

      await signUpAndLogin(seekerPage, seekerEmail, "Hidden", "Seeker", whitehorse.city, whitehorse.province);
      await expect(seekerPage.getByRole("heading", { name: "Discover Taskers" })).toBeVisible({
        timeout: 15000,
      });
      await expect(seekerPage.getByText("No taskers found")).toBeVisible({ timeout: 15000 });
      await expect(seekerPage.getByText(taskerName)).toHaveCount(0);
    } finally {
      await testProxy("cleanupConversations", { userEmail: seekerEmail });
      await testProxy("cleanupConversations", { userEmail: taskerEmail });
      await testProxy("deleteTestUser", { email: seekerEmail });
      await testProxy("deleteTestUser", { email: taskerEmail });
      await seekerContext.close();
      await taskerContext.close();
    }
  });

  test("canceled subscriptions remain visible until term end, then revert to ghost mode", async ({ browser }) => {
    const taskerEmail = `cancel_visibility_${Date.now()}@test.com`;
    const seekerEmail = `cancel_visibility_seeker_${Date.now()}@test.com`;
    const taskerName = "Visible Until Term End";

    const taskerContext = await browser.newContext();
    const taskerPage = await taskerContext.newPage();
    const seekerContext = await browser.newContext();
    const seekerPage = await seekerContext.newPage();

    try {
      await signUpAndLogin(taskerPage, taskerEmail, "Cancel", "Tasker", whitehorse.city, whitehorse.province);
      await completeTaskerOnboarding(taskerPage, {
        category: "Cleaning",
        displayName: taskerName,
        hourlyRate: "75",
        plan: "basic",
      });

      await testProxy("setTaskerLocationByEmail", {
        email: taskerEmail,
        lat: whitehorse.lat,
        lng: whitehorse.lng,
      });

      taskerPage.once("dialog", (dialog) => dialog.accept());
      await taskerPage.getByRole("button", { name: "Cancel subscription" }).click();
      await expect(taskerPage.getByText(/Cancellation is scheduled for/)).toBeVisible({
        timeout: 10000,
      });

      await signUpAndLogin(seekerPage, seekerEmail, "Visible", "Seeker", whitehorse.city, whitehorse.province);
      await expect(seekerPage.getByRole("heading", { name: "Discover Taskers" })).toBeVisible({
        timeout: 15000,
      });
      await expect(seekerPage.getByText(taskerName)).toBeVisible({ timeout: 15000 });

      await testProxy("expireTaskerSubscription", { email: taskerEmail });
      await seekerPage.reload();

      await expect(seekerPage.getByText("No taskers found")).toBeVisible({ timeout: 15000 });
      await expect(seekerPage.getByText(taskerName)).toHaveCount(0);
    } finally {
      await testProxy("cleanupConversations", { userEmail: seekerEmail });
      await testProxy("cleanupConversations", { userEmail: taskerEmail });
      await testProxy("deleteTestUser", { email: seekerEmail });
      await testProxy("deleteTestUser", { email: taskerEmail });
      await seekerContext.close();
      await taskerContext.close();
    }
  });
});
