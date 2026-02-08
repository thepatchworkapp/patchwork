import { Page } from "@playwright/test";

/**
 * Fetch OTP from Convex testing endpoint
 * @param email - Email address to fetch OTP for
 * @returns OTP code or undefined if not found
 */
export async function fetchOtp(email: string): Promise<string | undefined> {
  const convexSiteUrl = process.env.VITE_CONVEX_SITE_URL || process.env.VITE_CONVEX_URL?.replace(".convex.cloud", ".convex.site");
  if (!convexSiteUrl) throw new Error("VITE_CONVEX_SITE_URL or VITE_CONVEX_URL must be set");

  // Poll for OTP up to 10 seconds
  for (let i = 0; i < 20; i++) {
    const res = await fetch(`${convexSiteUrl}/test-proxy`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "getOtp", args: { email } }),
    });
    const data = await res.json();
    if (data.result) {
      return data.result;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return undefined;
}

/**
 * Complete signup flow: enter email, get OTP, verify, create profile
 * @param page - Playwright page object
 * @param email - Email address for signup
 * @param firstName - First name for profile
 * @param lastName - Last name for profile
 * @param city - City for profile
 */
export async function signUpAndLogin(
  page: Page,
  email: string,
  firstName: string,
  lastName: string,
  city: string
): Promise<void> {
  // Navigate to app
  await page.goto("http://localhost:5173");

  // Click sign in button
  await page.click('text=Sign in');

  // Enter email
  await page.fill('input[type="email"]', email);
  await page.click('button:has-text("Continue")');

  // Wait for OTP input to appear
  await page.waitForSelector('input[placeholder*="OTP"]', { timeout: 5000 });

  // Fetch OTP from testing endpoint
  const otp = await fetchOtp(email);
  if (!otp) {
    throw new Error(`Failed to fetch OTP for ${email}`);
  }

  // Enter OTP
  await page.fill('input[placeholder*="OTP"]', otp);
  await page.click('button:has-text("Verify")');

  // Wait for profile creation screen
  await page.waitForSelector('input[placeholder*="First name"]', {
    timeout: 5000,
  });

  // Fill profile information
  await page.fill('input[placeholder*="First name"]', firstName);
  await page.fill('input[placeholder*="Last name"]', lastName);
  await page.fill('input[placeholder*="City"]', city);

  // Submit profile
  await page.click('button:has-text("Complete Profile")');

  // Wait for navigation to home screen
  await page.waitForURL("http://localhost:5173", { timeout: 5000 });
}

/**
 * Login with existing user account
 * @param page - Playwright page object
 * @param email - Email address of existing user
 */
export async function loginExisting(page: Page, email: string): Promise<void> {
  // Navigate to app
  await page.goto("http://localhost:5173");

  // Click sign in button
  await page.click('text=Sign in');

  // Enter email
  await page.fill('input[type="email"]', email);
  await page.click('button:has-text("Continue")');

  // Wait for OTP input to appear
  await page.waitForSelector('input[placeholder*="OTP"]', { timeout: 5000 });

  // Fetch OTP from testing endpoint
  const otp = await fetchOtp(email);
  if (!otp) {
    throw new Error(`Failed to fetch OTP for ${email}`);
  }

  // Enter OTP
  await page.fill('input[placeholder*="OTP"]', otp);
  await page.click('button:has-text("Verify")');

  // Wait for navigation to home screen
  await page.waitForURL("http://localhost:5173", { timeout: 5000 });
}
