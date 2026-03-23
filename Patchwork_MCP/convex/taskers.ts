import { internalMutation, mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import {
  getEffectiveGhostMode,
  getEffectiveSubscriptionPlan,
  getEffectiveSubscriptionStatus,
  getDefaultSubscriptionTermMs,
  hasActiveSubscription,
} from "../lib/convex/subscriptionState";
import {
  searchTaskerResultValidator,
  taskerDetailValidator,
  taskerProfileResponseValidator,
} from "../lib/convex/validators";

const MAX_SCHEDULER_DELAY_MS = 2_147_483_647;

function buildSubscriptionView(profile: {
  subscriptionPlan: "none" | "tasker" | "basic" | "premium";
  subscriptionAccessType?: "weekly" | "lifetime";
  subscriptionStatus?: "inactive" | "active" | "cancel_at_period_end" | "expired";
  subscriptionEndsAt?: number;
  ghostMode: boolean;
}) {
  return {
    subscriptionPlan: getEffectiveSubscriptionPlan(profile),
    subscriptionStatus: getEffectiveSubscriptionStatus(profile),
    subscriptionEndsAt: profile.subscriptionEndsAt,
    hasActiveSubscription: hasActiveSubscription(profile),
    ghostMode: getEffectiveGhostMode(profile),
  };
}

function validateTaskerCategoryInput(args: {
  categoryBio: string;
  rateType: "hourly" | "fixed";
  hourlyRate?: number;
  fixedRate?: number;
  serviceRadius: number;
}) {
  if (args.categoryBio.length > 2000) throw new ConvexError("Category bio must be 2000 characters or less");
  if (args.serviceRadius < 1 || args.serviceRadius > 250) throw new ConvexError("Service radius must be between 1 and 250 km");
  if (args.hourlyRate !== undefined && (args.hourlyRate < 1 || args.hourlyRate > 100000000)) throw new ConvexError("Hourly rate must be between 1 and 1,000,000 (in cents)");
  if (args.fixedRate !== undefined && (args.fixedRate < 1 || args.fixedRate > 100000000)) throw new ConvexError("Fixed rate must be between 1 and 1,000,000 (in cents)");
}

async function buildTaskerProfileResponse(
  ctx: any,
  profile: {
    _id: any;
    userId: any;
    displayName: string;
    bio?: string;
    isOnboarded: boolean;
    rating: number;
    reviewCount: number;
    completedJobs: number;
    responseTime?: string;
    verified: boolean;
    subscriptionPlan: "none" | "tasker" | "basic" | "premium";
    subscriptionAccessType?: "weekly" | "lifetime";
    subscriptionStatus?: "inactive" | "active" | "cancel_at_period_end" | "expired";
    subscriptionEndsAt?: number;
    ghostMode: boolean;
    premiumPin?: string;
    foundersBadge?: {
      categoryId: any;
      awardedAt: number;
    };
    location?: {
      lat: number;
      lng: number;
    };
    geoPoint?: string;
    createdAt: number;
    updatedAt: number;
  },
) {
  const taskerCategories = await ctx.db
    .query("taskerCategories")
    .withIndex("by_taskerProfile", (q: any) => q.eq("taskerProfileId", profile._id))
    .take(20);

  const categoriesWithNames = await Promise.all(
    taskerCategories.map(async (tc: any) => {
      const category = await ctx.db.get(tc.categoryId);
      return {
        _id: tc._id,
        taskerProfileId: tc.taskerProfileId,
        userId: tc.userId,
        categoryId: tc.categoryId,
        bio: tc.bio,
        photos: tc.photos,
        rateType: tc.rateType,
        hourlyRate: tc.hourlyRate,
        fixedRate: tc.fixedRate,
        serviceRadius: tc.serviceRadius,
        rating: tc.rating,
        reviewCount: tc.reviewCount,
        completedJobs: tc.completedJobs,
        createdAt: tc.createdAt,
        updatedAt: tc.updatedAt,
        categoryName: category?.name ?? "Unknown",
        categorySlug: category?.slug ?? "unknown",
      };
    }),
  );

  return {
    _id: profile._id,
    userId: profile.userId,
    displayName: profile.displayName,
    bio: profile.bio,
    isOnboarded: profile.isOnboarded,
    rating: profile.rating,
    reviewCount: profile.reviewCount,
    completedJobs: profile.completedJobs,
    responseTime: profile.responseTime,
    verified: profile.verified,
    subscriptionPlan: profile.subscriptionPlan,
    subscriptionAccessType: profile.subscriptionAccessType,
    subscriptionStatus: profile.subscriptionStatus,
    subscriptionEndsAt: profile.subscriptionEndsAt,
    ghostMode: profile.ghostMode,
    premiumPin: profile.premiumPin,
    foundersBadge: profile.foundersBadge,
    location: profile.location,
    geoPoint: profile.geoPoint,
    createdAt: profile.createdAt,
    updatedAt: profile.updatedAt,
    ...buildSubscriptionView(profile),
    categories: categoriesWithNames,
  };
}

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
  returns: v.id("taskerProfiles"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const existingProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (existingProfile) {
      throw new ConvexError("Tasker profile already exists");
    }

    // Input validation
    if (args.displayName.length > 100) throw new ConvexError("Display name must be 100 characters or less");
    if (args.bio && args.bio.length > 2000) throw new ConvexError("Bio must be 2000 characters or less");
    if (args.categoryBio.length > 2000) throw new ConvexError("Category bio must be 2000 characters or less");
    if (args.serviceRadius < 1 || args.serviceRadius > 250) throw new ConvexError("Service radius must be between 1 and 250 km");
    if (args.hourlyRate !== undefined && (args.hourlyRate < 1 || args.hourlyRate > 100000000)) throw new ConvexError("Hourly rate must be between 1 and 1,000,000 (in cents)");
    if (args.fixedRate !== undefined && (args.fixedRate < 1 || args.fixedRate > 100000000)) throw new ConvexError("Fixed rate must be between 1 and 1,000,000 (in cents)");

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
      subscriptionStatus: "inactive",
      ghostMode: true,
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
  args: {},
  returns: v.union(taskerProfileResponseValidator, v.null()),
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

    return buildTaskerProfileResponse(ctx, profile);
  },
});

export const updateTaskerProfile = mutation({
  args: {
    displayName: v.optional(v.string()),
    bio: v.optional(v.string()),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    // Input validation
    if (args.displayName !== undefined && args.displayName.length > 100) throw new ConvexError("Display name must be 100 characters or less");
    if (args.bio !== undefined && args.bio.length > 2000) throw new ConvexError("Bio must be 2000 characters or less");

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

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      ...updates,
    });
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
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    const existingCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .first();

    if (existingCategory) {
      throw new ConvexError("Category already exists for this tasker");
    }

    validateTaskerCategoryInput(args);

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

    return null;
  },
});

export const updateTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .first();

    if (!category) {
      throw new ConvexError("Category not found");
    }

    validateTaskerCategoryInput(args);

    const updates = {
      bio: args.categoryBio,
      rateType: args.rateType,
      hourlyRate: args.rateType === "hourly" ? args.hourlyRate : undefined,
      fixedRate: args.rateType === "fixed" ? args.fixedRate : undefined,
      serviceRadius: args.serviceRadius,
      updatedAt: Date.now(),
    };

    await ctx.db.patch(category._id, updates);

    return buildTaskerProfileResponse(ctx, profile);
  },
});

export const getTaskerById = query({
  args: { taskerId: v.id("taskerProfiles") },
  returns: v.union(taskerDetailValidator, v.null()),
  handler: async (ctx, args) => {
    const profile = await ctx.db.get(args.taskerId);
    if (!profile) return null;

    const user = await ctx.db.get(profile.userId);
    if (!user) return null;

    const userPhotoUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
      .take(20);

    const categoriesWithNames = await Promise.all(
      taskerCategories.map(async (tc) => {
        const category = await ctx.db.get(tc.categoryId);
        const firstPhotoStorageId = tc.photos?.[0];
        const firstPhotoUrl = firstPhotoStorageId
          ? await ctx.storage.getUrl(firstPhotoStorageId)
          : null;
        return {
          id: tc._id,
          categoryId: tc.categoryId,
          categoryName: category?.name ?? "Unknown",
          categorySlug: category?.slug ?? "unknown",
          bio: tc.bio,
          photos: tc.photos,
          firstPhotoUrl,
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
        const reviewerPhotoUrl = reviewer?.photo
          ? await ctx.storage.getUrl(reviewer.photo)
          : null;
        return {
          id: r._id,
          rating: r.rating,
          text: r.text,
          reviewerName: reviewer?.name ?? "Anonymous",
          reviewerPhotoUrl,
          createdAt: r.createdAt,
        };
      })
    );

    return {
      id: profile._id,
      userId: profile.userId,
      displayName: profile.displayName,
      bio: profile.bio,
      rating: profile.rating,
      reviewCount: profile.reviewCount,
      completedJobs: profile.completedJobs,
      verified: profile.verified,
      userName: user.name,
      userPhoto: user.photo,
      userPhotoUrl,
      categories: categoriesWithNames,
      reviews: reviewsWithReviewers,
    };
  },
});

export const listFavouriteTaskers = query({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.array(searchTaskerResultValidator),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) return [];

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!seekerProfile) return [];

    const limit = Math.max(1, Math.min(args.limit ?? 50, 50));
    const favouriteUserIds = seekerProfile.favouriteTaskers.slice(0, limit);

    const results = await Promise.all(
      favouriteUserIds.map(async (favouriteUserId) => {
        const profile = await ctx.db
          .query("taskerProfiles")
          .withIndex("by_userId", (q) => q.eq("userId", favouriteUserId))
          .first();

        if (!profile || !profile.isOnboarded) {
          return null;
        }

        const taskerUser = await ctx.db.get(profile.userId);
        if (!taskerUser) {
          return null;
        }

        const categoryData = await ctx.db
          .query("taskerCategories")
          .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", profile._id))
          .first();

        if (!categoryData) {
          return null;
        }

        const category = await ctx.db.get(categoryData.categoryId);
        if (!category) {
          return null;
        }

        const avatarUrl = taskerUser.photo ? await ctx.storage.getUrl(taskerUser.photo) : null;
        const categoryPhotoStorageId = categoryData.photos?.[0];
        const categoryPhotoUrl = categoryPhotoStorageId
          ? await ctx.storage.getUrl(categoryPhotoStorageId)
          : null;

        return {
          id: profile._id,
          userId: profile.userId,
          name: profile.displayName,
          category: category.name,
          rating: categoryData.rating,
          reviews: categoryData.reviewCount,
          price: formatTaskerSummaryPrice(categoryData.rateType, categoryData.hourlyRate, categoryData.fixedRate),
          distance: "",
          verified: profile.verified,
          bio: categoryData.bio,
          completedJobs: profile.completedJobs,
          avatarUrl,
          categoryPhotoUrl,
        };
      })
    );

    return results.filter((result): result is NonNullable<typeof result> => result !== null);
  },
});

function formatTaskerSummaryPrice(
  rateType: "hourly" | "fixed",
  hourlyRate: number | undefined,
  fixedRate: number | undefined
): string {
  if (rateType === "hourly" && hourlyRate) {
    const dollars = hourlyRate / 100;
    return `$${dollars}/hr`;
  }
  if (rateType === "fixed" && fixedRate) {
    const dollars = fixedRate / 100;
    return `$${dollars} flat`;
  }
  return "$0/hr";
}

export const removeTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .first();

    if (!category) {
      throw new ConvexError("Category not found");
    }

    await ctx.db.delete(category._id);

    return null;
  },
});

export const updateSubscriptionPlan = mutation({
  args: {
    plan: v.literal("tasker"),
    accessType: v.optional(v.union(v.literal("weekly"), v.literal("lifetime"))),
    endsAt: v.optional(v.number()),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    const updates: any = {
      subscriptionPlan: args.plan,
      subscriptionAccessType: args.accessType,
      subscriptionStatus: "active",
      subscriptionEndsAt: args.accessType === "weekly" ? args.endsAt : undefined,
      ghostMode: false,
      updatedAt: Date.now(),
    };

    updates.premiumPin = undefined;

    await ctx.db.patch(profile._id, updates);

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      ...updates,
    });
  },
});

export const cancelSubscription = mutation({
  args: {},
  returns: taskerProfileResponseValidator,
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");
    if (!hasActiveSubscription(profile)) {
      throw new ConvexError("Active subscription required to cancel");
    }

    if (profile.subscriptionAccessType === "lifetime") {
      throw new ConvexError("Lifetime access does not renew and cannot be cancelled");
    }

    const endsAt =
      profile.subscriptionEndsAt ??
      Date.now() +
        getDefaultSubscriptionTermMs({
          subscriptionPlan: profile.subscriptionPlan,
          subscriptionAccessType: profile.subscriptionAccessType,
        });

    await ctx.db.patch(profile._id, {
      subscriptionStatus: "cancel_at_period_end",
      subscriptionEndsAt: endsAt,
      updatedAt: Date.now(),
    });

    await ctx.scheduler.runAfter(
      Math.min(Math.max(endsAt - Date.now(), 0), MAX_SCHEDULER_DELAY_MS),
      internal.taskers.expireSubscriptionAtTermEnd,
      {
      taskerProfileId: profile._id,
      expectedEndsAt: endsAt,
      },
    );

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      subscriptionStatus: "cancel_at_period_end",
      subscriptionEndsAt: endsAt,
    });
  },
});

export const expireSubscriptionAtTermEnd = internalMutation({
  args: {
    taskerProfileId: v.id("taskerProfiles"),
    expectedEndsAt: v.number(),
  },
  handler: async (ctx, args) => {
    const profile = await ctx.db.get(args.taskerProfileId);
    if (!profile) {
      return;
    }

    if (
      profile.subscriptionStatus !== "cancel_at_period_end" ||
      profile.subscriptionEndsAt !== args.expectedEndsAt ||
      profile.subscriptionEndsAt > Date.now()
    ) {
      return;
    }

    const remainingMs = profile.subscriptionEndsAt - Date.now();
    if (remainingMs > 0) {
      await ctx.scheduler.runAfter(
        Math.min(remainingMs, MAX_SCHEDULER_DELAY_MS),
        internal.taskers.expireSubscriptionAtTermEnd,
        args,
      );
      return;
    }

    await ctx.db.patch(profile._id, {
      subscriptionStatus: "expired",
      ghostMode: true,
      updatedAt: Date.now(),
    });
  },
});

export const setGhostMode = mutation({
  args: {
    ghostMode: v.boolean(),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new ConvexError("User not found");

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!profile) throw new ConvexError("Tasker profile not found");

    // Validate active subscription
    if (!hasActiveSubscription(profile)) {
      throw new ConvexError("Active subscription required to toggle ghost mode");
    }

    const updates: any = {
      ghostMode: args.ghostMode,
      updatedAt: Date.now(),
    };

    await ctx.db.patch(profile._id, updates);

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      ...updates,
    });
  },
});
