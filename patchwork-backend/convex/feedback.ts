import { mutation } from "./_generated/server";
import { ConvexError, v } from "convex/values";

const MAX_FEEDBACK_MESSAGE_LENGTH = 4000;

export const submit = mutation({
  args: {
    message: v.string(),
  },
  returns: v.id("feedbackSubmissions"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .unique();

    if (!user) throw new ConvexError("User not found");

    const message = args.message.trim();
    if (!message) {
      throw new ConvexError("Feedback message is required");
    }
    if (message.length > MAX_FEEDBACK_MESSAGE_LENGTH) {
      throw new ConvexError("Feedback message must be 4000 characters or less");
    }

    const now = Date.now();

    return await ctx.db.insert("feedbackSubmissions", {
      userId: user._id,
      message,
      createdAt: now,
      updatedAt: now,
    });
  },
});
