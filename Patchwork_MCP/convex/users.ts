import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createProfile = mutation({
  args: {
    name: v.string(),
    city: v.string(),
    province: v.string(),
    photo: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Check if user already exists
    const existing = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (existing) {
      throw new Error("User already exists");
    }

    const now = Date.now();

    const userId = await ctx.db.insert("users", {
      authId: identity.tokenIdentifier,
      email: identity.email!,
      emailVerified: identity.emailVerified ?? false,
      name: args.name,
      photo: args.photo,
      location: {
        city: args.city,
        province: args.province,
      },
      roles: {
        isSeeker: true,
        isTasker: false,
      },
      settings: {
        notificationsEnabled: true,
        locationEnabled: false,
      },
      createdAt: now,
      updatedAt: now,
    });

    // Create seeker profile
    await ctx.db.insert("seekerProfiles", {
      userId,
      jobsPosted: 0,
      completedJobs: 0,
      rating: 0,
      ratingCount: 0,
      favouriteTaskers: [],
      updatedAt: now,
    });

    return userId;
  },
});

export const getCurrentUser = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    return await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
  },
});
