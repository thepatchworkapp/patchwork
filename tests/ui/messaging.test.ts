import { test, expect, type Page } from '@playwright/test';
import { ConvexHttpClient } from "convex/browser";
import { api } from "../../Patchwork_MCP/convex/_generated/api";

const convexUrl = process.env.VITE_CONVEX_URL || process.env.CONVEX_URL;
if (!convexUrl) {
  throw new Error("Missing Convex URL. Set VITE_CONVEX_URL (or CONVEX_URL) to https://<deployment>.convex.cloud");
}
const convex = new ConvexHttpClient(convexUrl);

async function fetchOtp(email: string): Promise<string> {
  console.log(`[Test] Fetching OTP for ${email}...`);
  for (let i = 0; i < 30; i++) {
    // @ts-ignore - access testing api
    const otp = await convex.query(api.testing.getOtp, { email });
    if (otp) {
        console.log(`[Test] Found OTP for ${email}: ${otp}`);
        return otp;
    }
    await new Promise(r => setTimeout(r, 1000));
  }
  throw new Error(`Could not get OTP for ${email}`);
}

async function signUpAndLogin(page: Page, email: string, name: string) {
  console.log(`[Test] Navigating to / for ${email}`);
  
  await page.context().clearCookies();
  await page.goto('/');
  await page.evaluate(() => localStorage.clear());
  await page.evaluate(() => sessionStorage.clear());
  await page.reload();
  
  await page.waitForTimeout(1000);
  
  try {
      await page.getByText('Get Started').click({ timeout: 2000 });
      console.log(`[Test] Clicked Get Started`);
      await page.waitForTimeout(2000);
  } catch (e) {
  }
  
  try {
      await page.getByText('Skip').click({ timeout: 2000 });
      console.log(`[Test] Clicked Skip`);
      await page.waitForTimeout(1000);
  } catch (e) {
  }

  let isLoginPage = await page.getByText('Sign in to continue').isVisible();

  console.log(`[Test] Is Login Page: ${isLoginPage}`);
  
  if (!isLoginPage) {
     console.log(`[Test] Not on login page, trying to navigate to Profile to trigger auth`);
     const profileTab = page.getByRole('button', { name: 'Profile', exact: true });
     if (await profileTab.isVisible()) {
         await profileTab.click();
         await page.waitForTimeout(1000);
         isLoginPage = await page.getByText('Sign in to continue').isVisible();
         console.log(`[Test] Is Login Page after click: ${isLoginPage}`);
     } else {
         console.log(`[Test] Profile tab not found!`);
     }
  }
  
  if (await page.getByText('Continue with Email').isVisible()) {
      console.log(`[Test] Clicking Continue with Email`);
      await page.getByText('Continue with Email').click();
      
      await page.getByPlaceholder('your@email.com').fill(email);
      await page.getByRole('button', { name: 'Send Code' }).click();
      
      const otp = await fetchOtp(email);
      
      await page.locator('input[autocomplete="one-time-code"]').fill(otp);
      await page.getByRole('button', { name: 'Verify' }).click();
      
      await page.waitForTimeout(3000);
      
      if (await page.getByText('Create your profile').isVisible()) {
        console.log(`[Test] Creating profile for ${name}`);
        const nameParts = name.split(' ');
        await page.getByPlaceholder('Jenny').fill(nameParts[0]);
        await page.getByPlaceholder('Mabel').fill(nameParts[1] || 'User');
        await page.getByPlaceholder('Toronto', { exact: true }).fill('Toronto');
        await page.getByPlaceholder('ON', { exact: true }).fill('ON');
        await page.getByRole('button', { name: 'Continue' }).click();
        
        if (await page.getByText('Failed to create profile').isVisible() || await page.getByText('Please fill in all fields').isVisible()) {
             const bodyErr = await page.textContent('body');
             console.log(`[Test] Create Profile Error: ${bodyErr?.substring(0, 300)}`);
             throw new Error('Profile creation failed');
        }
        
        await page.waitForTimeout(2000);
      }
  }
  
  if (await page.getByText('Allow location access').first().isVisible()) {
      console.log(`[Test] Found Location Prompt, clicking Not Now`);
      await page.getByText('Not Now').click();
      await page.waitForTimeout(1000);
  }

  if (await page.getByText('Stay updated').first().isVisible()) {
      console.log(`[Test] Found Notification Prompt, clicking Maybe Later`);
      await page.getByText('Maybe Later').click();
      await page.waitForTimeout(1000);
  }

  try {
    await expect(page.getByText('Messages', { exact: true }).first()).toBeVisible({ timeout: 10000 });
  } catch (e) {
    const bodyFinal = await page.textContent('body');
    console.log(`[Test] Login failed/stuck. Body: ${bodyFinal?.substring(0, 500)}`);
    throw e;
  }
}

test.describe('End-to-End Messaging Flow', () => {
  
  test('verify db access', async () => {
      const email = `test_db_${Date.now()}@example.com`;
      // @ts-ignore
      await convex.mutation(api.testing.seedOtp, { email, otp: "999999" });
      const otp = await fetchOtp(email);
      expect(otp).toBe("999999");
  });

  test('complete messaging and proposal workflow', async ({ browser }) => {
    const taskerContext = await browser.newContext();
    const taskerPage = await taskerContext.newPage();
    const taskerEmail = `tasker_${Date.now()}@test.com`;
    
    await test.step('Tasker Signup', async () => {
      await signUpAndLogin(taskerPage, taskerEmail, 'Test Tasker');
    });
    
    await test.step('Tasker Onboarding', async () => {
      await taskerPage.goto('/profile');
      if (!taskerPage.url().includes('profile')) {
         await taskerPage.getByRole('button', { name: 'Profile', exact: true }).click();
      }
      
      const becomeTaskerBtn = taskerPage.getByText('Become a Tasker');
      if (await becomeTaskerBtn.isVisible()) {
        await becomeTaskerBtn.click();
        
        await taskerPage.getByPlaceholder('Display Name').fill('Pro Tasker');
        await taskerPage.getByRole('button', { name: 'Next' }).click();
        
        await taskerPage.locator('input[type="checkbox"]').first().click();
        await taskerPage.getByRole('button', { name: 'Next' }).click();
        
        await taskerPage.getByRole('button', { name: 'Skip' }).click();
        
        await taskerPage.getByPlaceholder('Tell clients about your experience...').fill('I am a pro.');
        await taskerPage.locator('input[type="number"]').first().fill('50');
        await taskerPage.getByRole('button', { name: 'Next' }).click();
        
        await taskerPage.locator('input[type="checkbox"]').click();
        await taskerPage.getByRole('button', { name: 'Complete Setup' }).click();
        
        await expect(taskerPage.getByText('Your Tasker profile is complete')).toBeVisible({ timeout: 10000 });
        await taskerPage.getByRole('button', { name: 'Subscribe' }).click();
        
        await taskerPage.getByText('Skip for now').click();
        await taskerPage.getByRole('button', { name: 'Ok' }).click();
      }
    });
    
    const seekerContext = await browser.newContext();
    const seekerPage = await seekerContext.newPage();
    const seekerEmail = `seeker_${Date.now()}@test.com`;
    
    await test.step('Seeker Signup', async () => {
      await signUpAndLogin(seekerPage, seekerEmail, 'Test Seeker');
    });
    
    await test.step('Seeker finds Tasker', async () => {
      console.log(`[Test] Force creating conversation...`);
      try {
          // @ts-ignore
          await convex.mutation(api.testing.forceCreateConversation, { 
              seekerEmail, 
              taskerEmail 
          });
          console.log(`[Test] Conversation created in backend`);
      } catch (e) {
          console.error(`[Test] Failed to create conversation:`, e);
          throw e;
      }
      
      console.log(`[Test] Clicking Messages tab`);
      await seekerPage.getByRole('button', { name: 'Messages', exact: true }).click();
      await seekerPage.waitForTimeout(2000);
      
      if (await seekerPage.getByText('No conversations yet').isVisible()) {
          console.log(`[Test] No conversations found. Reloading...`);
          await seekerPage.reload();
          await seekerPage.waitForTimeout(2000);
      }
      
      console.log(`[Test] Waiting for conversation item`);
      const bodyMsgs = await seekerPage.textContent('body');
      console.log(`[Test] Body on Messages: ${bodyMsgs?.substring(0, 300)}`);
      
      await expect(seekerPage.getByText('Tasker').first()).toBeVisible({ timeout: 5000 });
      await seekerPage.locator('button').filter({ hasText: 'just now' }).first().click();
    });
    
    const testMessage = "Hello, are you available?";

    await test.step('Send Message', async () => {
      try {
        await expect(seekerPage.getByText('Conversation')).toBeVisible({ timeout: 5000 });
      } catch (e) {
        const bodyChat = await seekerPage.textContent('body');
        console.log(`[Test] Failed to open chat. Body: ${bodyChat?.substring(0, 300)}`);
        throw e;
      }
      
      await seekerPage.getByPlaceholder('Type a message...').fill(testMessage);
      await seekerPage.getByRole('button').filter({ has: seekerPage.locator('svg.lucide-send') }).click();
      
      await expect(seekerPage.getByText(testMessage)).toBeVisible();
    });
    
    await test.step('Tasker Receives Message', async () => {
      await taskerPage.getByRole('button', { name: 'Messages', exact: true }).click();
      
      // Wait for Lock icon to disappear (indicating isTasker is true)
      const taskerTab = taskerPage.getByRole('button', { name: 'Tasker' });
      const lockIcon = taskerTab.locator('svg.lucide-lock');
      
      try {
        await expect(lockIcon).toBeHidden({ timeout: 10000 });
      } catch (e) {
        console.log(`[Test] Lock icon still visible. isTasker state might be lost?`);
      }
      
      await taskerPage.getByRole('button', { name: 'Tasker' }).click();
      
      await expect(taskerPage.getByText('Test Seeker').or(taskerPage.getByText('Seeker')).first()).toBeVisible({ timeout: 10000 });
      
      await expect(taskerPage.getByText(testMessage)).toBeVisible({ timeout: 10000 });
      
      await taskerPage.locator('button').filter({ hasText: testMessage }).first().click();
      
      await expect(taskerPage.getByText(testMessage)).toBeVisible();
    });

    
    await test.step('Tasker Sends Proposal', async () => {
      await taskerPage.getByRole('button', { name: 'Propose terms' }).click();
      
      await taskerPage.getByPlaceholder('85').fill('60');
      
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      const dateStr = tomorrow.toISOString().split('T')[0];
      
      await taskerPage.locator('input[type="date"]').fill(dateStr);
      await taskerPage.locator('input[type="time"]').fill('10:00');
      
      await taskerPage.getByRole('button', { name: 'Send Proposal' }).click();
      
      await expect(taskerPage.getByText('$60.00/hourly')).toBeVisible();
    });
    
    await test.step('Seeker Accepts Proposal', async () => {
      await expect(seekerPage.getByText('$60.00/hourly')).toBeVisible();
      
      await seekerPage.getByRole('button', { name: 'Accept' }).click();
      
      await expect(seekerPage.getByText('Proposal accepted')).toBeVisible();
      await expect(seekerPage.getByText('Job in progress')).toBeVisible();
    });
    
    await test.step('Verify Tasker Update', async () => {
      await expect(taskerPage.getByText('Proposal accepted')).toBeVisible();
      await expect(taskerPage.getByText('Job in progress')).toBeVisible();
    });
    
    console.log('✅ End-to-End Messaging Flow Completed');
  });
});
