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

export const getTaskerById = query({
  args: { taskerId: v.id("taskerProfiles") },
  handler: async (ctx, args) => {
    const profile = await ctx.db.get(args.taskerId);
    if (!profile) return null;

    const user = await ctx.db.get(profile.userId);
    if (!user) return null;

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
      .collect();

    const categoriesWithNames = await Promise.all(
      taskerCategories.map(async (tc) => {
        const category = await ctx.db.get(tc.categoryId);
        return {
          id: tc._id,
          categoryId: tc.categoryId,
          categoryName: category?.name ?? "Unknown",
          categorySlug: category?.slug ?? "unknown",
          bio: tc.bio,
          rateType: tc.rateType,
          hourlyRate: tc.hourlyRate,
          fixedRate: tc.fixedRate,
          serviceRadius: tc.serviceRadius,
          completedJobs: tc.completedJobs,
        };
      })
    );

    const reviews = await ctx.db
      .query("reviews")
      .withIndex("by_reviewee", (q) => q.eq("revieweeId", profile.userId))
      .order("desc")
      .take(10);

    const reviewsWithReviewers = await Promise.all(
      reviews.map(async (r) => {
        const reviewer = await ctx.db.get(r.reviewerId);
        return {
          id: r._id,
          rating: r.rating,
          text: r.text,
          reviewerName: reviewer?.name ?? "Anonymous",
          createdAt: r.createdAt,
        };
      })
    );

    return {
      id: profile._id,
      displayName: profile.displayName,
      bio: profile.bio,
      rating: profile.rating,
      reviewCount: profile.reviewCount,
      completedJobs: profile.completedJobs,
      verified: profile.verified,
      userName: user.name,
      userPhoto: user.photo,
      categories: categoriesWithNames,
      reviews: reviewsWithReviewers,
    };
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

export const updateSubscriptionPlan = mutation({
  args: {
    plan: v.union(v.literal("basic"), v.literal("premium")),
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
      subscriptionPlan: args.plan,
      ghostMode: false,
      updatedAt: Date.now(),
    };

    // Generate 6-digit premiumPin for premium subscribers only
    if (args.plan === "premium") {
      updates.premiumPin = Math.floor(100000 + Math.random() * 900000).toString();
    }

    await ctx.db.patch(profile._id, updates);
  },
});

export const setGhostMode = mutation({
  args: {
    ghostMode: v.boolean(),
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

    // Validate active subscription
    if (profile.subscriptionPlan === "none") {
      throw new Error("Active subscription required to toggle ghost mode");
    }

    const updates: any = {
      ghostMode: args.ghostMode,
      updatedAt: Date.now(),
    };

    await ctx.db.patch(profile._id, updates);
  },
});
