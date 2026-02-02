import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createTaskerProfile = mutation({
  args: {
    displayName: v.string(),
    bio: v.optional(v.string()),
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    photos: v.optional(v.array(v.id("_storage"))),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    const existingProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (existingProfile) {
      throw new Error("Tasker profile already exists");
    }

    const now = Date.now();

    const profileId = await ctx.db.insert("taskerProfiles", {
      userId: user._id,
      displayName: args.displayName,
      bio: args.bio,
      isOnboarded: true,
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      verified: false,
      subscriptionPlan: "none",
      ghostMode: false,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.db.insert("taskerCategories", {
      taskerProfileId: profileId,
      userId: user._id,
      categoryId: args.categoryId,
      bio: args.categoryBio,
      photos: args.photos ?? [],
      rateType: args.rateType,
      hourlyRate: args.hourlyRate,
      fixedRate: args.fixedRate,
      serviceRadius: args.serviceRadius,
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.db.patch(user._id, {
      roles: {
        ...user.roles,
        isTasker: true,
      },
      updatedAt: now,
    });

    return profileId;
  },
});

export const getTaskerProfile = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) return null;

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) return null;

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
      .collect();

    const categoriesWithNames = await Promise.all(
      taskerCategories.map(async (tc) => {
        const category = await ctx.db.get(tc.categoryId);
        return {
          ...tc,
          categoryName: category?.name ?? "Unknown",
          categorySlug: category?.slug ?? "unknown",
        };
      })
    );

    return {
      ...profile,
      categories: categoriesWithNames,
    };
  },
});

export const updateTaskerProfile = mutation({
  args: {
    displayName: v.optional(v.string()),
    bio: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new Error("Tasker profile not found");

    const updates: any = {
      updatedAt: Date.now(),
    };

    if (args.displayName !== undefined) {
      updates.displayName = args.displayName;
    }

    if (args.bio !== undefined) {
      updates.bio = args.bio;
    }

    await ctx.db.patch(profile._id, updates);
  },
});

export const addTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new Error("Tasker profile not found");

    const existingCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
      .filter((q) => q.eq(q.field("categoryId"), args.categoryId))
      .first();

    if (existingCategory) {
      throw new Error("Category already exists for this tasker");
    }

    const now = Date.now();

    await ctx.db.insert("taskerCategories", {
      taskerProfileId: profile._id,
      userId: user._id,
      categoryId: args.categoryId,
      bio: args.categoryBio,
      photos: [],
      rateType: args.rateType,
      hourlyRate: args.hourlyRate,
      fixedRate: args.fixedRate,
      serviceRadius: args.serviceRadius,
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const removeTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new Error("Tasker profile not found");

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
      .filter((q) => q.eq(q.field("categoryId"), args.categoryId))
      .first();

    if (!category) {
      throw new Error("Category not found");
    }

    await ctx.db.delete(category._id);
  },
});
