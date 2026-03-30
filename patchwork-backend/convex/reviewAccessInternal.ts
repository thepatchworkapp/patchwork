import { ConvexError, v } from "convex/values";
import { authComponent } from "./auth";
import { internalMutation } from "./_generated/server";
import { setReviewAccessEnabled } from "./reviewAccess";

const REVIEW_SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export const ensureReviewAuthSession = internalMutation({
  args: {
    email: v.string(),
    name: v.string(),
    sessionToken: v.string(),
    userAgent: v.string(),
  },
  handler: async (ctx, args) => {
    const authAdapter = authComponent.adapter(ctx);

    let authUser = await authAdapter.findOne({
      model: "user",
      where: [{ field: "email", operator: "eq", value: args.email }],
    });

    if (!authUser) {
      authUser = await authAdapter.create({
        model: "user",
        data: {
          name: args.name,
          email: args.email,
          emailVerified: true,
          image: null,
          createdAt: new Date().getTime(),
          updatedAt: new Date().getTime(),
        },
      });
    }

    const betterAuthUserId = String(authUser?.id ?? authUser?._id ?? "");
    if (!betterAuthUserId) {
      throw new ConvexError("Review auth user could not be created");
    }

    const now = Date.now();
    await authAdapter.create({
      model: "session",
      data: {
        expiresAt: now + REVIEW_SESSION_TTL_MS,
        token: args.sessionToken,
        createdAt: now,
        updatedAt: now,
        ipAddress: "",
        userAgent: args.userAgent,
        userId: betterAuthUserId,
      },
    });

    return { betterAuthUserId };
  },
});

export const bootstrap = internalMutation({
  args: {
    enabled: v.boolean(),
    betterAuthUserId: v.optional(v.string()),
    email: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    return await setReviewAccessEnabled(ctx, args.enabled, args.betterAuthUserId, args.email);
  },
});
