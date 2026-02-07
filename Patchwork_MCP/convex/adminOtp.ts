import { mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

function getAdminEmailAllowlist(): Set<string> {
  // Support both ADMIN_EMAILS (comma-separated) and legacy ADMIN_EMAIL (single).
  const raw =
    process.env.ADMIN_EMAILS ||
    process.env.ADMIN_EMAIL ||
    "";
  const emails = raw
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return new Set(emails);
}

const ADMIN_EMAILS = getAdminEmailAllowlist();
const OTP_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
const MAX_VERIFY_ATTEMPTS = 5;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;

function generateOtp() {
  const random = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return random.toString().padStart(6, "0");
}

async function hashOtp(otp: string) {
  const bytes = new TextEncoder().encode(otp);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export const sendOTP = mutation({
  args: {
    email: v.string(),
  },
  handler: async (ctx, args) => {
    if (!ADMIN_EMAILS.has(args.email.toLowerCase())) {
      throw new Error("Invalid email. Not authorized.");
    }

    const otp = generateOtp();
    const otpHash = await hashOtp(otp);
    const now = Date.now();

    const existing = await ctx.db
      .query("adminOtps")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .take(100);

    const latestExisting = existing
      .sort((a, b) => b.createdAt - a.createdAt)
      .at(0);

    if (latestExisting && now - latestExisting.createdAt < OTP_RESEND_COOLDOWN_MS) {
      throw new Error("Please wait before requesting a new OTP.");
    }

    // Delete any existing OTP for this email

    for (const record of existing) {
      await ctx.db.delete(record._id);
    }

    await ctx.db.insert("adminOtps", {
      email: args.email,
      otpHash,
      createdAt: now,
      expiresAt: now + OTP_EXPIRY_MS,
      verifyAttempts: 0,
    });

    await ctx.runMutation(internal.resend.sendOtpEmail, {
      email: args.email,
      otp,
      purpose: "admin-login",
    });

    return { email: args.email };
  },
});

export const verifyOTP = mutation({
  args: {
    email: v.string(),
    otp: v.string(),
  },
  handler: async (ctx, args) => {
    if (!ADMIN_EMAILS.has(args.email.toLowerCase())) {
      throw new Error("Invalid email. Not authorized.");
    }

    const otpHash = await hashOtp(args.otp);

    const record = await ctx.db
      .query("adminOtps")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .order("desc")
      .first();

    if (!record) {
      throw new Error("No OTP found. Please request a new one.");
    }

    const now = Date.now();
    if (now > record.expiresAt) {
      await ctx.db.delete(record._id);
      throw new Error("OTP has expired. Please request a new one.");
    }

    if (record.verifyAttempts >= MAX_VERIFY_ATTEMPTS) {
      await ctx.db.delete(record._id);
      throw new Error("Too many failed attempts. Please request a new OTP.");
    }

    if (record.otpHash !== otpHash) {
      await ctx.db.patch(record._id, {
        verifyAttempts: record.verifyAttempts + 1,
      });
      throw new Error("Invalid OTP");
    }

    await ctx.db.delete(record._id);

    return { verified: true, email: args.email };
  },
});
