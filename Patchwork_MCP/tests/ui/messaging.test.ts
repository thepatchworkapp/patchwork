import { test, expect } from "@playwright/test";

test.describe("Messaging Flow", () => {
  test("should load messages screen", async ({ page }) => {
    await page.goto("http://localhost:5173");
    
    // Navigate to Messages
    await page.click('text=Messages');
    
    // Verify Messages screen loaded
    await expect(page.locator('text=Messages')).toBeVisible();
    await expect(page.locator('text=Seeker')).toBeVisible();
  });

  test("should show conversation list", async ({ page }) => {
    await page.goto("http://localhost:5173");
    
    // Navigate to Messages
    await page.click('text=Messages');
    
    // Wait for conversations to load
    await page.waitForTimeout(1000);
    
    // Verify conversation list or empty state
    const hasConversations = await page.locator('.conversation-item').count() > 0;
    const hasEmptyState = await page.locator('text=No conversations').isVisible().catch(() => false);
    
    expect(hasConversations || hasEmptyState).toBeTruthy();
  });

  test("should navigate to chat screen", async ({ page }) => {
    await page.goto("http://localhost:5173");
    
    // Navigate to Messages
    await page.click('text=Messages');
    await page.waitForTimeout(1000);
    
    // Try to click first conversation if exists
    const firstConversation = page.locator('.conversation-item').first();
    const count = await firstConversation.count();
    
    if (count > 0) {
      await firstConversation.click();
      
      // Verify Chat screen loaded
      await expect(page.locator('input[placeholder="Type a message..."]')).toBeVisible();
    }
  });

  test("should send a message", async ({ page }) => {
    await page.goto("http://localhost:5173");
    
    // Navigate to Messages
    await page.click('text=Messages');
    await page.waitForTimeout(1000);
    
    // Click first conversation
    const firstConversation = page.locator('.conversation-item').first();
    if (await firstConversation.count() > 0) {
      await firstConversation.click();
      await page.waitForTimeout(500);
      
      // Type and send message
      const input = page.locator('input[placeholder="Type a message..."]');
      await input.fill("Test message from E2E");
      await input.press('Enter');
      
      // Verify message appears
      await expect(page.locator('text=Test message from E2E')).toBeVisible();
    }
  });

  test("should display proposal card", async ({ page }) => {
    await page.goto("http://localhost:5173");
    
    // Navigate to Messages and open conversation
    await page.click('text=Messages');
    await page.waitForTimeout(1000);
    
    const firstConversation = page.locator('.conversation-item').first();
    if (await firstConversation.count() > 0) {
      await firstConversation.click();
      await page.waitForTimeout(500);
      
      // Check for proposal card or proposal button
      const hasProposalButton = await page.locator('text=Propose terms').isVisible().catch(() => false);
      const hasProposalCard = await page.locator('.proposal-card').count() > 0;
      
      // At least one should be present
      expect(hasProposalButton || hasProposalCard).toBeTruthy();
    }
  });
});
