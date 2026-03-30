import { Resend } from "@convex-dev/resend";
import { v } from "convex/values";
import { components } from "./_generated/api";
import { internalMutation } from "./_generated/server";

const resend = new Resend(components.resend, {
  testMode: false,
});

const FROM_EMAIL = process.env.OTP_FROM_EMAIL || "otp@diaper.exchange";

export const sendOtpEmail = internalMutation({
  args: {
    email: v.string(),
    otp: v.string(),
    purpose: v.union(v.literal("admin-login"), v.literal("email-login"), v.literal("email-signup")),
  },
  handler: async (ctx, args) => {
    const subject = args.purpose === "admin-login"
      ? "Your Patchwork Admin verification code"
      : "Your Patchwork verification code";

    const html = `
      <div style="font-family: Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #111827; line-height: 1.6;">
        <p>Your one-time verification code is:</p>
        <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px; margin: 16px 0;">${args.otp}</p>
        <p>This code expires in 10 minutes.</p>
        <p>If you did not request this code, you can safely ignore this email.</p>
      </div>
    `;

    await resend.sendEmail(ctx, {
      from: `Patchwork <${FROM_EMAIL}>`,
      to: args.email,
      subject,
      html,
      text: `Your verification code is ${args.otp}. This code expires in 10 minutes.`,
    });
  },
});
