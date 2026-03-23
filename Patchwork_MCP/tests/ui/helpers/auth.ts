import { expect, type Locator, type Page } from "@playwright/test";

const appUrl = process.env.PATCHWORK_APP_URL || "http://localhost:5173";
const convexSiteUrl =
  process.env.VITE_CONVEX_SITE_URL ||
  process.env.VITE_CONVEX_URL?.replace(".convex.cloud", ".convex.site");

if (!convexSiteUrl) {
  throw new Error("VITE_CONVEX_SITE_URL or VITE_CONVEX_URL must be set");
}

async function isVisible(locator: Locator, timeout = 2000): Promise<boolean> {
  try {
    await locator.waitFor({ state: "visible", timeout });
    return true;
  } catch {
    return false;
  }
}

export async function testProxy(
  action: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const res = await fetch(`${convexSiteUrl}/test-proxy`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, args }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || "Test proxy call failed");
  }
  return data.result;
}

export async function fetchOtp(email: string): Promise<string> {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const otp = await testProxy("getOtp", { email });
    if (typeof otp === "string" && otp.length > 0) {
      return otp;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  throw new Error(`Failed to fetch OTP for ${email}`);
}

export async function signUpAndLogin(
  page: Page,
  email: string,
  firstName: string,
  lastName: string,
  city: string,
  province = "ON",
): Promise<void> {
  await page.context().clearCookies();
  await page.goto(appUrl);
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
  });
  await page.reload();

  const getStartedButton = page.getByRole("button", { name: "Get Started" });
  if (await isVisible(getStartedButton)) {
    await getStartedButton.click();
  }

  const onboardingSkip = page.getByRole("button", { name: "Skip" });
  if (await isVisible(onboardingSkip)) {
    await onboardingSkip.click();
  }

  await expect(page.getByText("Sign in to continue")).toBeVisible({ timeout: 10000 });
  await page.getByRole("button", { name: "Continue with Email" }).click();

  await page.getByPlaceholder("your@email.com").fill(email);
  await page.getByRole("button", { name: "Send Code" }).click();

  const otpInput = page.locator('input[autocomplete="one-time-code"]');
  await expect(otpInput).toBeVisible({ timeout: 10000 });
  await otpInput.fill(await fetchOtp(email));
  await page.getByRole("button", { name: /Verify/ }).click();

  const createProfileHeading = page.getByText("Create your profile");
  if (await isVisible(createProfileHeading, 10000)) {
    await page.getByPlaceholder("Jenny").fill(firstName);
    await page.getByPlaceholder("Mabel").fill(lastName);
    await page.getByPlaceholder("Toronto", { exact: true }).fill(city);
    await page.getByPlaceholder("ON", { exact: true }).fill(province);
    await page.getByRole("button", { name: "Continue" }).click();
  }

  const locationSkipButton = page.getByRole("button", { name: "Not Now" });
  if (await isVisible(locationSkipButton, 10000)) {
    await locationSkipButton.click();
  }

  const notificationsSkipButton = page.getByRole("button", { name: "Maybe Later" });
  if (await isVisible(notificationsSkipButton, 10000)) {
    await notificationsSkipButton.click();
  }

  await expect(page.getByRole("button", { name: "Messages", exact: true })).toBeVisible({
    timeout: 10000,
  });
}

export async function completeTaskerOnboarding(
  page: Page,
  options?: {
    category?: string;
    displayName?: string;
    bio?: string;
    hourlyRate?: string;
    plan?: "basic" | "premium" | "skip";
  },
): Promise<void> {
  const {
    category = "Cleaning",
    displayName = "Pro Tasker",
    bio = "Professional, responsive, and ready for local jobs.",
    hourlyRate = "60",
    plan = "basic",
  } = options ?? {};

  await page.getByRole("button", { name: "Profile", exact: true }).click();

  const signUpButton = page.getByRole("button", { name: "Sign up as a Tasker" });
  if (!(await isVisible(signUpButton, 10000))) {
    await expect(page.getByText("Tasker Profile")).toBeVisible({ timeout: 10000 });
    return;
  }

  await signUpButton.click();
  await expect(page.getByText("Business basics")).toBeVisible({ timeout: 10000 });

  await page.getByPlaceholder("Your business or full name").fill(displayName);
  await page.getByText(category, { exact: true }).click();
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page.getByText("Service area & pricing")).toBeVisible({ timeout: 10000 });
  await page.getByPlaceholder("0.00").first().fill(hourlyRate);
  await page.locator("textarea").fill(bio);
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page.getByText("Review & accept")).toBeVisible({ timeout: 10000 });
  await page.locator('input[type="checkbox"]').check();
  await page.getByRole("button", { name: "Complete Setup" }).click();

  await expect(page.getByText("Your Tasker profile is complete")).toBeVisible({ timeout: 10000 });
  await page.getByRole("button", { name: "Subscribe" }).click();

  await expect(page.getByText("Subscription")).toBeVisible({ timeout: 10000 });
  if (plan === "skip") {
    await page.getByRole("button", { name: "Skip for now" }).click();
    await page.getByRole("button", { name: "Ok" }).click();
  } else {
    await page.getByText(plan === "basic" ? "Basic" : "Premium", { exact: true }).click();
    await page
      .getByRole("button", {
        name: plan === "basic" ? "Subscribe to Basic" : "Subscribe to Premium",
      })
      .click();
  }

  await expect(page.getByText("Tasker Profile")).toBeVisible({ timeout: 10000 });
}
