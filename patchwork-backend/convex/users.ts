import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import { currentUserValidator } from "../lib/convex/validators";
import { authComponent } from "./auth";
import {
  deleteImageAssetIfUnreferenced,
  getDisplayStorageId,
  getImageAssetStorageIds,
  getOwnedImageAsset,
  getUserPhotoImageAssetDto,
  markImageAssetDeleted,
} from "./imageAssetHelpers";
import { requireAppUser } from "./authHelpers";

const ACCOUNT_CLEANUP_BATCH_SIZE = 1000;
const MAX_BADGE_CONVERSATIONS = 200;

function tombstoneEmail(userId: string) {
  return `deleted+${userId}@deleted.patchwork.local`;
}

function tombstoneAuthId(userId: string, now: number) {
  return `deleted:${userId}:${now}`;
}

function authUserIdFromTokenIdentifier(tokenIdentifier: string) {
  const marker = tokenIdentifier.lastIndexOf("|");
  if (marker === -1 || marker === tokenIdentifier.length - 1) {
    return null;
  }
  return tokenIdentifier.slice(marker + 1);
}

async function deleteAuthModelIfPresent(ctx: any, model: string, where?: Array<any>) {
  const authAdapter = await authComponent.adapter(ctx)({});
  try {
    await authAdapter.deleteMany({ model, where });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (
      message.includes(`Model "${model}" not found in schema`) ||
      message.includes('Component "betterAuth" is not registered')
    ) {
      return;
    }
    throw error;
  }
}

async function deleteAuthRecordsForIdentity(ctx: any, tokenIdentifier: string, email: string) {
  const authUserId = authUserIdFromTokenIdentifier(tokenIdentifier);
  const authCleanupTasks = [
    deleteAuthModelIfPresent(ctx, "user", [{ field: "email", operator: "eq" as const, value: email }]),
  ];

  if (authUserId) {
    const userIdFilter = [{ field: "userId", operator: "eq" as const, value: authUserId }];
    authCleanupTasks.push(
      deleteAuthModelIfPresent(ctx, "session", userIdFilter),
      deleteAuthModelIfPresent(ctx, "account", userIdFilter),
      deleteAuthModelIfPresent(ctx, "twoFactor", userIdFilter),
      deleteAuthModelIfPresent(ctx, "passkey", userIdFilter),
      deleteAuthModelIfPresent(ctx, "oauthAccessToken", userIdFilter),
      deleteAuthModelIfPresent(ctx, "oauthConsent", userIdFilter)
    );
  }

  await Promise.all(authCleanupTasks);
}

async function deleteLooseStorageFiles(ctx: any, storageIds: Set<string>) {
  let deleted = 0;
  let failed = 0;

  for (const storageId of storageIds) {
    try {
      await ctx.storage.delete(storageId);
      deleted += 1;
    } catch (error) {
      failed += 1;
      console.warn("[AccountDeletion] Failed to delete uploaded storage file", {
        storageId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return { deleted, failed };
}

async function deleteFavouriteRowsForUser(ctx: any, userId: any) {
  while (true) {
    const rows = await ctx.db
      .query("favouriteTaskers")
      .withIndex("by_seeker_createdAt", (q: any) => q.eq("seekerId", userId))
      .take(ACCOUNT_CLEANUP_BATCH_SIZE);
    if (!rows.length) break;
    await Promise.all(rows.map((row: any) => ctx.db.delete(row._id)));
  }

  while (true) {
    const rows = await ctx.db
      .query("favouriteTaskers")
      .withIndex("by_tasker_user", (q: any) => q.eq("taskerUserId", userId))
      .take(ACCOUNT_CLEANUP_BATCH_SIZE);
    if (!rows.length) break;
    await Promise.all(rows.map((row: any) => ctx.db.delete(row._id)));
  }
}

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

export const registerPushToken = mutation({
  args: {
    token: v.string(),
    environment: v.union(v.literal("sandbox"), v.literal("production")),
  },
  returns: v.object({ registered: v.boolean() }),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    const token = args.token.trim();
    if (!token) {
      throw new ConvexError("Push token is required");
    }
    if (token.length > 512) {
      throw new ConvexError("Push token is too long");
    }

    const now = Date.now();
    const existingToken = await ctx.db
      .query("pushTokens")
      .withIndex("by_token", (q) => q.eq("token", token))
      .unique();

    if (existingToken) {
      await ctx.db.patch(existingToken._id, {
        userId: user._id,
        platform: "ios",
        environment: args.environment,
        disabledAt: undefined,
        updatedAt: now,
      });
      return { registered: true };
    }

    await ctx.db.insert("pushTokens", {
      userId: user._id,
      token,
      platform: "ios",
      environment: args.environment,
      createdAt: now,
      updatedAt: now,
    });

    return { registered: true };
  },
});

export const unregisterPushToken = mutation({
  args: {
    token: v.string(),
  },
  returns: v.object({ unregistered: v.boolean() }),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    const existingToken = await ctx.db
      .query("pushTokens")
      .withIndex("by_token", (q) => q.eq("token", args.token.trim()))
      .unique();

    if (!existingToken || existingToken.userId !== user._id) {
      return { unregistered: false };
    }

    await ctx.db.patch(existingToken._id, {
      disabledAt: Date.now(),
      updatedAt: Date.now(),
    });

    return { unregistered: true };
  },
});

export const getUnreadBadgeCount = query({
  args: {},
  returns: v.number(),
  handler: async (ctx) => {
    const { user } = await requireAppUser(ctx);

    const seekerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_seeker_lastMessage", (q) => q.eq("seekerId", user._id))
      .take(MAX_BADGE_CONVERSATIONS);
    const taskerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_tasker_lastMessage", (q) => q.eq("taskerId", user._id))
      .take(MAX_BADGE_CONVERSATIONS);

    return [...seekerConversations, ...taskerConversations].reduce((total, conversation) => {
      if (conversation.seekerId === user._id) {
        return total + (conversation.seekerUnreadCount ?? 0);
      }
      return total + (conversation.taskerUnreadCount ?? 0);
    }, 0);
  },
});

export const updateProfile = mutation({
  args: {
    name: v.string(),
    city: v.string(),
    province: v.string(),
  },
  returns: currentUserValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    if (args.name.length > 100) throw new ConvexError("Name must be 100 characters or less");
    if (args.city.length > 100) throw new ConvexError("City must be 100 characters or less");
    if (args.province.length > 100) throw new ConvexError("Province must be 100 characters or less");

    const now = Date.now();
    await ctx.db.patch(user._id, {
      name: args.name,
      location: {
        ...user.location,
        city: args.city,
        province: args.province,
      },
      updatedAt: now,
    });

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

export const deleteAccount = mutation({
  args: {},
  returns: v.object({
    deleted: v.boolean(),
    authCleanupSucceeded: v.boolean(),
    imageAssetsDeleted: v.number(),
    imageAssetStorageFailures: v.number(),
    looseStorageDeleted: v.number(),
    looseStorageFailures: v.number(),
  }),
  handler: async (ctx) => {
    const { identity, user } = await requireAppUser(ctx);

    const activeSeekerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_seeker_status", (q) => q.eq("seekerId", user._id).eq("status", "in_progress"))
      .take(1);
    const pendingSeekerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_seeker_status", (q) => q.eq("seekerId", user._id).eq("status", "pending"))
      .take(1);
    const activeTaskerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_tasker_status", (q) => q.eq("taskerId", user._id).eq("status", "in_progress"))
      .take(1);
    const pendingTaskerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_tasker_status", (q) => q.eq("taskerId", user._id).eq("status", "pending"))
      .take(1);

    if (
      activeSeekerJobs.length ||
      pendingSeekerJobs.length ||
      activeTaskerJobs.length ||
      pendingTaskerJobs.length
    ) {
      throw new ConvexError("Resolve active jobs before deleting your account.");
    }

    const now = Date.now();
    const ownedImageAssets = await ctx.db
      .query("imageAssets")
      .withIndex("by_owner", (q) => q.eq("ownerUserId", user._id))
      .collect();
    const imageAssetStorageIds = new Set(
      ownedImageAssets.flatMap((imageAsset) =>
        getImageAssetStorageIds(imageAsset).map((storageId) => String(storageId))
      )
    );
    const looseStorageIds = new Set<string>();

    if (user.photo && !imageAssetStorageIds.has(String(user.photo))) {
      looseStorageIds.add(String(user.photo));
    }

    const sentMessages = await ctx.db
      .query("messages")
      .withIndex("by_sender", (q) => q.eq("senderId", user._id))
      .collect();
    await Promise.all(
      sentMessages.map(async (message) => {
        for (const attachment of message.attachments ?? []) {
          if (!imageAssetStorageIds.has(String(attachment))) {
            looseStorageIds.add(String(attachment));
          }
        }

        if (message.attachments?.length) {
          await ctx.db.patch(message._id, {
            attachments: undefined,
            updatedAt: now,
          });
        }
      })
    );

    const jobRequests = await ctx.db
      .query("jobRequests")
      .withIndex("by_seeker", (q) => q.eq("seekerId", user._id))
      .collect();
    await Promise.all(
      jobRequests.map(async (jobRequest) => {
        for (const photo of jobRequest.photos ?? []) {
          if (!imageAssetStorageIds.has(String(photo))) {
            looseStorageIds.add(String(photo));
          }
        }
        await ctx.db.delete(jobRequest._id);
      })
    );

    const feedbackSubmissions = await ctx.db
      .query("feedbackSubmissions")
      .withIndex("by_userId_createdAt", (q) => q.eq("userId", user._id))
      .collect();
    await Promise.all(feedbackSubmissions.map((feedback) => ctx.db.delete(feedback._id)));

    const blocksCreated = await ctx.db
      .query("userBlocks")
      .withIndex("by_blocker_createdAt", (q) => q.eq("blockerId", user._id))
      .collect();
    const blocksReceived = await ctx.db
      .query("userBlocks")
      .withIndex("by_blocked_createdAt", (q) => q.eq("blockedId", user._id))
      .collect();
    const blockIds = new Set([...blocksCreated, ...blocksReceived].map((block) => block._id));
    await Promise.all(Array.from(blockIds).map((blockId) => ctx.db.delete(blockId)));

    const reportsSubmitted = await ctx.db
      .query("userReports")
      .withIndex("by_reporter_createdAt", (q) => q.eq("reporterId", user._id))
      .collect();
    const reportsReceived = await ctx.db
      .query("userReports")
      .withIndex("by_reported_createdAt", (q) => q.eq("reportedUserId", user._id))
      .collect();
    const reportIds = new Set([...reportsSubmitted, ...reportsReceived].map((report) => report._id));
    await Promise.all(Array.from(reportIds).map((reportId) => ctx.db.delete(reportId)));

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .collect();
    await Promise.all(taskerCategories.map((category) => ctx.db.delete(category._id)));

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .unique();
    if (taskerProfile) {
      await ctx.db.delete(taskerProfile._id);
    }

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .unique();
    if (seekerProfile) {
      await ctx.db.delete(seekerProfile._id);
    }

    await deleteFavouriteRowsForUser(ctx, user._id);

    await ctx.db.patch(user._id, {
      authId: tombstoneAuthId(user._id, now),
      email: tombstoneEmail(user._id),
      emailVerified: false,
      name: "Deleted User",
      photo: undefined,
      photoAssetId: undefined,
      location: {
        city: "",
        province: "",
      },
      roles: {
        isSeeker: false,
        isTasker: false,
      },
      settings: {
        notificationsEnabled: false,
        locationEnabled: false,
      },
      updatedAt: now,
    });

    let imageAssetsDeleted = 0;
    let imageAssetStorageFailures = 0;
    for (const imageAsset of ownedImageAssets) {
      const result = await markImageAssetDeleted(ctx, imageAsset);
      if (imageAsset.status !== "deleted") {
        imageAssetsDeleted += 1;
      }
      imageAssetStorageFailures += result.failed;
    }

    const looseStorageResult = await deleteLooseStorageFiles(ctx, looseStorageIds);
    let authCleanupSucceeded = true;
    try {
      await deleteAuthRecordsForIdentity(ctx, identity.tokenIdentifier, user.email);
    } catch (error) {
      authCleanupSucceeded = false;
      console.warn("[AccountDeletion] Failed to delete auth records", {
        userId: user._id,
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return {
      deleted: true,
      authCleanupSucceeded,
      imageAssetsDeleted,
      imageAssetStorageFailures,
      looseStorageDeleted: looseStorageResult.deleted,
      looseStorageFailures: looseStorageResult.failed,
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
    const previousPhotoAssetId = user.photoAssetId;

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

    if (previousPhotoAssetId && previousPhotoAssetId !== args.photoAssetId) {
      await deleteImageAssetIfUnreferenced(ctx, previousPhotoAssetId, user._id);
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
