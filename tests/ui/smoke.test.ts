import { expect, test } from "@playwright/test";
import {
  completeTaskerOnboarding,
  signUpAndLogin,
  testProxy,
} from "../../Patchwork_MCP/tests/ui/helpers/auth";
import { generateTestId } from "../../Patchwork_MCP/tests/ui/helpers/cleanup";

const testId = generateTestId();
const seekerEmail = `${testId}_seeker@test.com`;
const taskerEmail = `${testId}_tasker@test.com`;

test.describe("Smoke Test Suite", () => {
  test.describe.configure({ timeout: 180000 });

  test.beforeAll(async ({ browser }) => {
    await testProxy("ensureCategoryExists", { name: "Cleaning" });

    const context = await browser.newContext();
    const page = await context.newPage();
    try {
      await signUpAndLogin(page, taskerEmail, "Tasker", "Joe", "New York");
    } finally {
      await context.close();
    }
  });

  test.afterAll(async () => {
    await testProxy("cleanupConversations", { userEmail: seekerEmail });
    await testProxy("cleanupConversations", { userEmail: taskerEmail });
    await testProxy("deleteTestUser", { email: seekerEmail });
    await testProxy("deleteTestUser", { email: taskerEmail });
  });

  test("Verify localhost core seeker and tasker flows", async ({ page }) => {
    await signUpAndLogin(page, seekerEmail, "Seeker", "Test", "New York");

    await expect(page.getByRole("button", { name: "Seek", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Jobs", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Messages", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Profile", exact: true })).toBeVisible();

    await page.getByRole("button", { name: "Profile", exact: true }).click();
    await expect(page.getByText("Seeker Test")).toBeVisible();
    await expect(page.getByText("New York")).toBeVisible();

    await page.getByRole("button", { name: "Messages", exact: true }).click();
    await expect(page.getByRole("heading", { name: "Messages" })).toBeVisible();
    await expect(page.getByText("No conversations yet.")).toBeVisible();

    await testProxy("forceCreateConversation", {
      seekerEmail,
      taskerEmail,
    });

    await page.getByRole("button", { name: "Seek", exact: true }).click();
    await page.getByRole("button", { name: "Messages", exact: true }).click();

    const conversationButton = page.getByRole("button", {
      name: /Open conversation with/,
    });
    await expect(conversationButton.first()).toBeVisible({ timeout: 10000 });
    await conversationButton.first().click();

    await expect(page.getByPlaceholder("Type a message...")).toBeVisible();
    await page.getByPlaceholder("Type a message...").fill("Hello from Smoke Test");
    await page.getByRole("button", { name: "Send message" }).click();
    await expect(page.getByText("Hello from Smoke Test")).toBeVisible();

    await page.getByRole("button", { name: "Back" }).click();
    await expect(page.getByRole("heading", { name: "Messages" })).toBeVisible();

    await page.getByRole("button", { name: "Jobs", exact: true }).click();
    await expect(page.getByRole("heading", { name: "Jobs" })).toBeVisible();

    await completeTaskerOnboarding(page, {
      category: "Cleaning",
      displayName: "Seeker Test Services",
      hourlyRate: "55",
      plan: "basic",
    });

    await expect(page.getByText("Tasker Profile")).toBeVisible();
    await expect(page.getByText("Cleaning")).toBeVisible();
    await expect(page.getByRole("button", { name: "Sign up as a Tasker" })).toHaveCount(0);
  });
});
