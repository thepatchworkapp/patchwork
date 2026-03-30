import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import { currentUserValidator } from "../lib/convex/validators";

export const createProfile = mutation({
  args: {
    name: v.string(),
    city: v.string(),
    province: v.string(),
    photo: v.optional(v.id("_storage")),
  },
  returns: v.id("users"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Not authenticated");

    // Check if user already exists
    const existing = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .unique();

    if (existing) {
      // Return existing user ID (idempotent) instead of throwing
      return existing._id;
    }

    // Input validation
    if (args.name.length > 100) throw new ConvexError("Name must be 100 characters or less");
    if (args.city.length > 100) throw new ConvexError("City must be 100 characters or less");
    if (args.province.length > 100) throw new ConvexError("Province must be 100 characters or less");

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
  args: {},
  returns: v.union(currentUserValidator, v.null()),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .unique();

    if (!user) {
      return null;
    }

    return {
      _id: user._id,
      authId: user.authId,
      email: user.email,
      emailVerified: user.emailVerified,
      name: user.name,
      photo: user.photo,
      location: user.location,
      roles: user.roles,
      settings: user.settings,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  },
});

export const updateLocation = mutation({
  args: {
    lat: v.number(),
    lng: v.number(),
    source: v.union(v.literal("gps"), v.literal("manual")),
  },
  returns: v.id("users"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .unique();
    
    if (!user) throw new ConvexError("User not found");

    // Coordinate validation
    if (args.lat < -90 || args.lat > 90) throw new ConvexError("Latitude must be between -90 and 90");
    if (args.lng < -180 || args.lng > 180) throw new ConvexError("Longitude must be between -180 and 180");

    const now = Date.now();

    await ctx.db.patch(user._id, {
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

    if (user.roles.isTasker) {
      const scheduledSyncTaskerGeoJob = await ctx.scheduler.runAfter(0, internal.location.syncTaskerGeo, {
        userId: user._id,
        lat: args.lat,
        lng: args.lng,
      });
      void scheduledSyncTaskerGeoJob;
    }

    return user._id;
  },
});
