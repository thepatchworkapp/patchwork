import { createClient, type GenericCtx } from "@convex-dev/better-auth";
import { convex, crossDomain } from "@convex-dev/better-auth/plugins";
import { components, api, internal } from "./_generated/api";
import type { DataModel } from "./_generated/dataModel";
import { query } from "./_generated/server";
import { betterAuth } from "better-auth/minimal";
import { emailOTP } from "better-auth/plugins";
import authConfig from "./auth.config";

const siteUrl = process.env.SITE_URL || "http://localhost:5173";
const trustedOrigins = Array.from(
  new Set(
    (process.env.TRUSTED_ORIGINS || `${siteUrl},http://localhost:5173,http://localhost:5174`)
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean)
  )
);
const enableTestingHelpers =
  process.env.ENABLE_TESTING_HELPERS === "true" ||
  (process.env.NODE_ENV || "development") !== "production";

export const authComponent = createClient<DataModel>(components.betterAuth);

export const createAuth = (ctx: GenericCtx<DataModel>) => {
  return betterAuth({
    trustedOrigins,
    database: authComponent.adapter(ctx),
    
    socialProviders: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID!,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      },
    },
    
    plugins: [
      emailOTP({
        async sendVerificationOTP({ email, otp, type }) {
          try {
            await ctx.runMutation(internal.resend.sendOtpEmail, {
              email,
              otp,
              purpose: type === "sign-up" ? "email-signup" : "email-login",
            });

            if (enableTestingHelpers) {
              await ctx.runMutation(api.testing.seedOtp, { email, otp });
            }
          } catch (error) {
            console.error("Failed to send OTP email:", error);
            throw error;
          }
        },
      }),
      crossDomain({ siteUrl }),
      convex({ authConfig }),
    ],
  });
};

export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    return authComponent.getAuthUser(ctx);
  },
});
