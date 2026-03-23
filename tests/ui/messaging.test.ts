import { expect, test } from "@playwright/test";
import {
  completeTaskerOnboarding,
  signUpAndLogin,
  testProxy,
} from "../../Patchwork_MCP/tests/ui/helpers/auth";

test.describe("End-to-End Messaging Flow", () => {
  test.describe.configure({ timeout: 240000 });

  test.beforeAll(async () => {
    await testProxy("ensureCategoryExists", { name: "Cleaning" });
  });

  test("complete messaging and proposal workflow", async ({ browser }) => {
    const taskerEmail = `tasker_${Date.now()}@test.com`;
    const seekerEmail = `seeker_${Date.now()}@test.com`;

    const taskerContext = await browser.newContext();
    const taskerPage = await taskerContext.newPage();
    const seekerContext = await browser.newContext();
    const seekerPage = await seekerContext.newPage();

    try {
      await test.step("Tasker signup and onboarding", async () => {
        await signUpAndLogin(taskerPage, taskerEmail, "Test", "Tasker", "Toronto");
        await completeTaskerOnboarding(taskerPage, {
          category: "Cleaning",
          displayName: "Pro Tasker",
          hourlyRate: "60",
          plan: "basic",
        });
      });

      await test.step("Seeker signup", async () => {
        await signUpAndLogin(seekerPage, seekerEmail, "Test", "Seeker", "Toronto");
      });

      await test.step("Seed conversation and open chat", async () => {
        await testProxy("forceCreateConversation", {
          seekerEmail,
          taskerEmail,
        });

        await seekerPage.getByRole("button", { name: "Messages", exact: true }).click();
        const seekerConversation = seekerPage.getByRole("button", {
          name: /Open conversation with/,
        });
        await expect(seekerConversation.first()).toBeVisible({ timeout: 10000 });
        await seekerConversation.first().click();
      });

      const seekerMessage = "Hello, are you available?";

      await test.step("Seeker sends a message", async () => {
        await seekerPage.getByPlaceholder("Type a message...").fill(seekerMessage);
        await seekerPage.getByRole("button", { name: "Send message" }).click();
        await expect(seekerPage.getByText(seekerMessage)).toBeVisible();
      });

      await test.step("Tasker receives the message", async () => {
        await taskerPage.getByRole("button", { name: "Messages", exact: true }).click();
        await taskerPage.getByRole("button", { name: "Tasker", exact: true }).click();

        const taskerConversation = taskerPage.getByRole("button", {
          name: /Open conversation with/,
        });
        await expect(taskerConversation.first()).toBeVisible({ timeout: 10000 });
        await taskerConversation.first().click();

        await expect(taskerPage.getByText(seekerMessage)).toBeVisible({ timeout: 10000 });
      });

      await test.step("Tasker sends proposal", async () => {
        await taskerPage.getByRole("button", { name: "Propose terms" }).click();
        await taskerPage.getByPlaceholder("85").fill("60");

        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dateStr = tomorrow.toISOString().split("T")[0];

        await taskerPage.locator('input[type="date"]').fill(dateStr);
        await taskerPage.locator('input[type="time"]').fill("10:00");
        await taskerPage.getByRole("button", { name: "Send Proposal" }).click();

        await expect(taskerPage.getByText("$60.00/hourly")).toBeVisible();
      });

      await test.step("Seeker accepts proposal", async () => {
        await expect(seekerPage.getByText("$60.00/hourly")).toBeVisible({ timeout: 10000 });
        await seekerPage.getByRole("button", { name: "Accept" }).click();

        await expect(seekerPage.getByText("Proposal accepted")).toBeVisible();
        await expect(seekerPage.getByText("Job in progress")).toBeVisible();
      });

      await test.step("Tasker sees accepted job", async () => {
        await expect(taskerPage.getByText("Proposal accepted")).toBeVisible({ timeout: 10000 });
        await expect(taskerPage.getByText("Job in progress")).toBeVisible({ timeout: 10000 });
      });
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
