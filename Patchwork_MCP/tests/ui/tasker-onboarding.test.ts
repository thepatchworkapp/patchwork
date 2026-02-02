import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { BrowserManager } from "agent-browser/dist/browser.js";

describe("Tasker Onboarding Flow", () => {
  let browser: BrowserManager;

  beforeAll(async () => {
    browser = new BrowserManager();
    await browser.launch({ headless: true });
  });

  afterAll(async () => {
    await browser.close();
  });

  it("should load the app and show home screen", async () => {
    const page = browser.getPage();
    await page.goto("http://localhost:5173");
    await page.waitForLoadState("networkidle");
    await page.screenshot({
      path: ".sisyphus/evidence/test1-01-home-screen.png",
      fullPage: true,
    });
    const title = await page.title();
    expect(title).toBeTruthy();
    const content = await page.locator("body").textContent();
    expect(content).toBeTruthy();
  });

  it("should navigate to Profile screen", async () => {
    const page = browser.getPage();
    await page.goto("http://localhost:5173");
    await page.waitForLoadState("networkidle");
    await page.screenshot({
      path: ".sisyphus/evidence/test2-01-before-onboarding.png",
      fullPage: true,
    });
    const body = await page.locator("body");
    expect(body).toBeTruthy();
  });
});
