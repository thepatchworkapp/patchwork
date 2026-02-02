import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const ADMIN_EMAIL = "daveald@gmail.com";
const OTP_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes

export const sendOTP = mutation({
  args: {
    email: v.string(),
    otp: v.string(),
  },
  handler: async (ctx, args) => {
    if (args.email !== ADMIN_EMAIL) {
      throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
    }

    if (!/^\d{6}$/.test(args.otp)) {
      throw new Error("Invalid OTP format");
    }

    // Delete any existing OTP for this email
    const existing = await ctx.db
      .query("otps")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
    }

    // Store new OTP
    const id = await ctx.db.insert("otps", {
      email: args.email,
      otp: args.otp,
      createdAt: Date.now(),
    });

    return { id, email: args.email };
  },
});

export const verifyOTP = mutation({
  args: {
    email: v.string(),
    otp: v.string(),
  },
  handler: async (ctx, args) => {
    if (args.email !== ADMIN_EMAIL) {
      throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
    }

    const record = await ctx.db
      .query("otps")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (!record) {
      throw new Error("No OTP found. Please request a new one.");
    }

    const now = Date.now();
    if (now - record.createdAt > OTP_EXPIRY_MS) {
      await ctx.db.delete(record._id);
      throw new Error("OTP has expired. Please request a new one.");
    }

    if (record.otp !== args.otp) {
      throw new Error("Invalid OTP");
    }

    await ctx.db.delete(record._id);

    return { verified: true, email: args.email };
  },
});
