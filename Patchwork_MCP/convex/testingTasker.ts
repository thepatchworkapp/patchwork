import { v } from "convex/values";
import { mutation } from "./_generated/server";
import { internal } from "./_generated/api";

export const forceGenerateUploadUrl = mutation({
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});

export const forceCreateTaskerProfile = mutation({
  args: {
    email: v.string(),
    displayName: v.string(),
    bio: v.string(),
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    photoStorageId: v.optional(v.id("_storage")),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
    lat: v.number(),
    lng: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) throw new Error(`User not found: ${args.email}`);
    
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
      photos: args.photoStorageId ? [args.photoStorageId] : [],
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
      location: {
        ...user.location,
        coordinates: {
          lat: args.lat,
          lng: args.lng,
        },
      },
      settings: {
        ...user.settings,
        locationEnabled: true,
      },
      updatedAt: now,
    });
    
    await ctx.scheduler.runAfter(0, internal.location.syncTaskerGeo, {
      userId: user._id,
      lat: args.lat,
      lng: args.lng,
    });
    
    return { profileId, userId: user._id };
  },
});
