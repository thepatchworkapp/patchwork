import { expect, test, describe } from "vitest";
import { generateOTP, getAdminEmail } from "../lib/auth";

describe("auth functions", () => {
  test("generateOTP creates 6-digit code", () => {
    const otp = generateOTP();

    expect(otp).toBeDefined();
    expect(typeof otp).toBe("string");
    expect(otp.length).toBe(6);
    expect(/^\d{6}$/.test(otp)).toBe(true);
  });

  test("generateOTP produces different values on multiple calls", () => {
    const otp1 = generateOTP();
    const otp2 = generateOTP();
    const otp3 = generateOTP();

    expect(otp1).not.toBe(otp2);
    expect(otp2).not.toBe(otp3);
  });

  test("generateOTP produces values in valid range", () => {
    for (let i = 0; i < 100; i++) {
      const otp = generateOTP();
      const num = parseInt(otp);
      expect(num).toBeGreaterThanOrEqual(100000);
      expect(num).toBeLessThan(1000000);
    }
  });

  test("getAdminEmail returns hardcoded admin email", () => {
    const email = getAdminEmail();

    expect(email).toBe("daveald@gmail.com");
  });

  test("getAdminEmail is consistent", () => {
    const email1 = getAdminEmail();
    const email2 = getAdminEmail();

    expect(email1).toBe(email2);
  });
});
