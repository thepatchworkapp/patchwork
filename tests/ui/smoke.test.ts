import { test, expect, Page } from "@playwright/test";
import { generateTestId } from "../../Patchwork_MCP/tests/ui/helpers/cleanup";
import { fetchOtp, signUpAndLogin } from "../../Patchwork_MCP/tests/ui/helpers/auth";

const convexSiteUrl = process.env.VITE_CONVEX_SITE_URL || process.env.VITE_CONVEX_URL?.replace(".convex.cloud", ".convex.site");
if (!convexSiteUrl) throw new Error("Missing VITE_CONVEX_SITE_URL or VITE_CONVEX_URL");

async function testProxy(action: string, args: Record<string, unknown>): Promise<unknown> {
  const res = await fetch(`${convexSiteUrl}/test-proxy`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, args }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Test proxy call failed");
  return data.result;
}

// Unique test ID for this run to avoid collisions
const testId = generateTestId();
const seekerEmail = `${testId}_seeker@test.com`;
const taskerEmail = `${testId}_tasker@test.com`;

test.describe("Smoke Test Suite", () => {
  test.beforeAll(async ({ browser }) => {
    // 1. Setup: Ensure category exists
    await testProxy("ensureCategoryExists", { name: "Cleaning" });

    // 2. Setup: Create a secondary user (Tasker) to enable Chat testing
    // We use a separate browser context to avoid interfering with the main test state
    const context = await browser.newContext();
    const page = await context.newPage();
    try {
      // Create the Tasker user
      await signUpAndLogin(page, taskerEmail, "Tasker", "Joe", "New York");
    } finally {
      await context.close();
    }
  });

  test.afterAll(async () => {
    // Cleanup: Delete test data
    // We clean up conversations first to avoid foreign key issues (though not strictly enforced in Convex usually)
    await testProxy("cleanupConversations", { userEmail: seekerEmail });
    await testProxy("deleteTestUser", { email: seekerEmail });
    await testProxy("deleteTestUser", { email: taskerEmail });
  });

  test("Verify all 7 Convex-wired screens", async ({ page }) => {
    // Step 1: Auth (Sign In)
    await page.goto("http://localhost:5173");
    await page.click('text=Sign in');
    await page.fill('input[type="email"]', seekerEmail);
    await page.click('button:has-text("Continue")');
    
    // Assert & Snapshot: OTP Input Visible
    await page.waitForSelector('input[placeholder*="OTP"]');
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/01-signin.png", fullPage: true });

    // Complete Auth
    const otp = await fetchOtp(seekerEmail);
    if (!otp) throw new Error(`Failed to fetch OTP for ${seekerEmail}`);
    await page.fill('input[placeholder*="OTP"]', otp);
    await page.click('button:has-text("Verify")');

    // Step 2: Create Profile
    await page.waitForSelector('input[placeholder*="First name"]');
    await page.fill('input[placeholder*="First name"]', "Seeker");
    await page.fill('input[placeholder*="Last name"]', "Test");
    await page.fill('input[placeholder*="City"]', "New York");
    
    // Snapshot: Create Profile Form
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/02-create-profile.png", fullPage: true });
    
    await page.click('button:has-text("Complete Profile")');
    
    // Assert: Redirect to Home
    await page.waitForURL("http://localhost:5173");
    // Snapshot: Home Screen
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/03-home.png", fullPage: true });

    // Step 3: Profile Screen
    await page.click('text=Profile');
    await expect(page.locator('text=Seeker Test')).toBeVisible();
    await expect(page.locator('text=New York')).toBeVisible();
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/04-profile.png", fullPage: true });

    // Step 4: Categories Screen
    // Navigate via "Browse" tab which lists categories
    await page.click('text=Browse');
    // Verify at least one category is visible (Cleaning should be there from setup)
    await expect(page.locator('text=Cleaning')).toBeVisible();
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/05-categories.png", fullPage: true });

    // Step 5: Messages Screen
    await page.click('text=Messages');
    // Screen should load (empty state is fine initially)
    await page.waitForTimeout(500); // Wait for potential loading
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/06-messages.png", fullPage: true });

    // Step 6: Chat Screen
    // To test Chat, we need a conversation. We seed it now using the backend.
    await testProxy("forceCreateConversation", {
      seekerEmail,
      taskerEmail
    });
    
    // Reload messages to see the new conversation
    await page.click('text=Home'); // Navigate away
    await page.click('text=Messages'); // Navigate back to trigger refresh
    
    // Open the conversation
    // Use .first() in case there are multiple (should be 1)
    await page.locator('.conversation-item').first().click();
    
    // Verify Chat UI
    await page.waitForSelector('input[placeholder="Type a message..."]');
    await page.fill('input[placeholder="Type a message..."]', "Hello from Smoke Test");
    await page.keyboard.press('Enter');
    
    // Verify message appears
    await expect(page.locator('text=Hello from Smoke Test')).toBeVisible();
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/07-chat.png", fullPage: true });
    
    // Go back to navigate to other screens
    await page.click('button:has-text("Back")'); // or icon
    // Wait for back navigation to complete
    await page.waitForSelector('text=Messages');

    // Step 7: Jobs Screen
    await page.click('text=Jobs');
    // Verify screen loads
    await expect(page.locator('text=Jobs')).toBeVisible(); // Heading
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/08-jobs.png", fullPage: true });

    // Step 8: Tasker Onboarding
    await page.click('text=Profile');
    await page.click('button:has-text("Sign up as a Tasker")');
    
    // Step 1: Business Basics
    await expect(page.locator('text=Become a Tasker')).toBeVisible();
    await page.click('text=Cleaning'); // Select category
    await page.click('button:has-text("Continue")');
    
    // Step 2: Details
    await page.waitForSelector('textarea'); // Bio
    await page.fill('textarea', "I am a professional cleaner for testing.");
    // Usually "Next" or "Continue".
    await page.locator('button:has-text("Next"), button:has-text("Continue")').click();

    // Step 4: Review (Step 3 is skipped in routing)
    await page.waitForSelector('text=Review & accept');
    await page.click('input[type="checkbox"]'); // Accept terms
    await page.click('button:has-text("Complete Setup")');

    // Success Screen
    // App.tsx -> navigate("tasker-success")
    // TaskerSuccess.tsx likely says "Success".
    // I'll wait for URL or Text.
    await expect(page.locator('text=Success').or(page.locator('text=Welcome'))).toBeVisible();
    await page.screenshot({ path: ".sisyphus/evidence/smoke-test/09-tasker-onboarding.png", fullPage: true });
  });
});
