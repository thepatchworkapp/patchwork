import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import { currentUserValidator } from "../lib/convex/validators";
import {
  getDisplayStorageId,
  getOwnedImageAsset,
  getUserPhotoImageAssetDto,
} from "./imageAssetHelpers";
import { requireAppUser } from "./authHelpers";

export const createProfile = mutation({
  args: {
    name: v.string(),
    city: v.string(),
    province: v.string(),
    photoAssetId: v.optional(v.id("imageAssets")),
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
      if (args.photoAssetId) {
        const imageAsset = await getOwnedImageAsset(ctx, args.photoAssetId, existing._id, {
          purpose: "userPhoto",
          requireActive: true,
        });

        await ctx.db.patch(existing._id, {
          photoAssetId: imageAsset._id,
          photo: getDisplayStorageId(imageAsset),
          updatedAt: Date.now(),
        });
      }

      // Return existing user ID (idempotent) instead of throwing
      return existing._id;
    }

    if (args.photoAssetId) {
      throw new ConvexError("photoAssetId can only be set on an existing profile");
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
      photoAssetId: undefined,
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

    const photoImage = await getUserPhotoImageAssetDto(ctx, user, true);

    return {
      _id: user._id,
      authId: user.authId,
      email: user.email,
      emailVerified: user.emailVerified,
      name: user.name,
      photo: user.photo,
      photoAssetId: user.photoAssetId,
      photoImage,
      location: user.location,
      roles: user.roles,
      settings: user.settings,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  },
});

export const updateProfilePhoto = mutation({
  args: {
    photoAssetId: v.union(v.id("imageAssets"), v.null()),
  },
  returns: currentUserValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const now = Date.now();
    if (args.photoAssetId === null) {
      await ctx.db.patch(user._id, {
        photoAssetId: undefined,
        photo: undefined,
        updatedAt: now,
      });
    } else {
      const imageAsset = await getOwnedImageAsset(ctx, args.photoAssetId, user._id, {
        purpose: "userPhoto",
        requireActive: true,
      });

      await ctx.db.patch(user._id, {
        photoAssetId: imageAsset._id,
        photo: getDisplayStorageId(imageAsset),
        updatedAt: now,
      });
    }

    const updatedUser = await ctx.db.get(user._id);
    if (!updatedUser) {
      throw new ConvexError("User not found");
    }

    const photoImage = await getUserPhotoImageAssetDto(ctx, updatedUser, true);

    return {
      _id: updatedUser._id,
      authId: updatedUser.authId,
      email: updatedUser.email,
      emailVerified: updatedUser.emailVerified,
      name: updatedUser.name,
      photo: updatedUser.photo,
      photoAssetId: updatedUser.photoAssetId,
      photoImage,
      location: updatedUser.location,
      roles: updatedUser.roles,
      settings: updatedUser.settings,
      createdAt: updatedUser.createdAt,
      updatedAt: updatedUser.updatedAt,
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
