import { expect, test } from "@playwright/test";
import {
  completeTaskerOnboarding,
  signUpAndLogin,
  testProxy,
} from "../../Patchwork_MCP/tests/ui/helpers/auth";

test.describe("Tasker Onboarding Flow", () => {
  test.describe.configure({ timeout: 180000 });

  test.beforeAll(async () => {
    await testProxy("ensureCategoryExists", { name: "Cleaning" });
  });

  test("creates a tasker profile and keeps tasker UI unlocked after reload", async ({ page }) => {
    const email = `tasker_onboarding_${Date.now()}@test.com`;

    try {
      await signUpAndLogin(page, email, "Taylor", "Tasker", "Toronto");

      await completeTaskerOnboarding(page, {
        category: "Cleaning",
        displayName: "Taylor Tasker",
        hourlyRate: "65",
        plan: "basic",
      });

      await page.reload();
      await expect(page.getByRole("button", { name: "Profile", exact: true })).toBeVisible({
        timeout: 10000,
      });

      await page.getByRole("button", { name: "Profile", exact: true }).click();
      await expect(page.getByText("Tasker Profile")).toBeVisible({ timeout: 10000 });

      await page.getByRole("button", { name: "Messages", exact: true }).click();
      await page.getByRole("button", { name: "Tasker", exact: true }).click();
      await expect(page.getByText("No conversations yet.")).toBeVisible();
      await expect(page.getByText("Become a Tasker")).toHaveCount(0);
    } finally {
      await testProxy("cleanupConversations", { userEmail: email });
      await testProxy("deleteTestUser", { email });
    }
  });
});
