import { action, internalQuery, mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import {
  getEffectiveGhostMode,
  getEffectiveSubscriptionPlan,
  getEffectiveSubscriptionStatus,
  getEffectiveSubscriptionTier,
  hasActivePremiumPinAccess,
  hasActiveSubscription,
} from "../lib/convex/subscriptionState";
import {
  searchTaskerResultValidator,
  taskerDetailValidator,
  taskerProfileResponseValidator,
} from "../lib/convex/validators";
import { buildTaskerSummaryDto } from "../lib/convex/dtoTaskers";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";
import {
  deleteImageAssetIfUnreferenced,
  getOwnedImageAsset,
  getOwnedImageAssets,
  getTaskerCategoryPortfolioImageDtos,
  getTaskerProfileImageAssetDto,
  getUserPhotoImageAssetDto,
  toCompatibilityPhotos,
} from "./imageAssetHelpers";

const MAX_CATEGORY_BIO_LENGTH = 500;
const MAX_CATEGORY_PORTFOLIO_ASSETS = 10;
const MAX_TASKER_PROFILE_LINKS = 10;
const MAX_TASKER_PROFILE_LINK_LENGTH = 300;
const DEFAULT_FAVOURITE_LIMIT = 50;
const MAX_FAVOURITE_LIMIT = 50;

const favouriteStatusValidator = v.object({
  isFavourite: v.boolean(),
});

function buildSubscriptionView(profile: {
  subscriptionPlan: "none" | "tasker";
  subscriptionAccessType?: "subscription" | "lifetime";
  subscriptionTier?: "basic" | "premium" | "founders";
  subscriptionActiveAccessTypes?: Array<"subscription" | "lifetime">;
  subscriptionStatus?: "inactive" | "active" | "cancel_at_period_end" | "expired";
  subscriptionEndsAt?: number;
  ghostMode: boolean;
}) {
  return {
    subscriptionPlan: getEffectiveSubscriptionPlan(profile),
    subscriptionTier: getEffectiveSubscriptionTier(profile),
    subscriptionStatus: getEffectiveSubscriptionStatus(profile),
    subscriptionEndsAt: profile.subscriptionEndsAt,
    hasActiveSubscription: hasActiveSubscription(profile),
    ghostMode: getEffectiveGhostMode(profile),
  };
}

function buildPremiumPinView(profile: {
  subscriptionPlan: "none" | "tasker";
  subscriptionAccessType?: "subscription" | "lifetime";
  subscriptionTier?: "basic" | "premium" | "founders";
  subscriptionStatus?: "inactive" | "active" | "cancel_at_period_end" | "expired";
  subscriptionEndsAt?: number;
  ghostMode: boolean;
  premiumPin?: string;
}) {
  if (
    typeof profile.premiumPin !== "string" ||
    !hasActivePremiumPinAccess(profile) ||
    (profile.subscriptionTier !== "premium" && profile.subscriptionTier !== "founders")
  ) {
    return undefined;
  }

  return {
    code: profile.premiumPin,
    status: "active" as const,
    tier: profile.subscriptionTier,
  };
}

function validateTaskerCategoryInput(args: {
  categoryBio: string;
  rateType: "hourly" | "fixed";
  hourlyRate?: number;
  fixedRate?: number;
  serviceRadius: number;
}) {
  if (args.categoryBio.length > MAX_CATEGORY_BIO_LENGTH) throw new ConvexError("Category bio must be 500 characters or less");
  if (args.serviceRadius < 1 || args.serviceRadius > 250) throw new ConvexError("Service radius must be between 1 and 250 km");
  if (args.hourlyRate !== undefined && (args.hourlyRate < 1 || args.hourlyRate > 100000000)) throw new ConvexError("Hourly rate must be between 1 and 1,000,000 (in cents)");
  if (args.fixedRate !== undefined && (args.fixedRate < 1 || args.fixedRate > 100000000)) throw new ConvexError("Fixed rate must be between 1 and 1,000,000 (in cents)");
}

type TaskerPhotoSource = "user" | "custom";

function normalizeTaskerPhotoSource(photoSource?: TaskerPhotoSource, photoAssetId?: Id<"imageAssets">): TaskerPhotoSource {
  if (photoSource) {
    return photoSource;
  }
  return photoAssetId ? "custom" : "user";
}

function validatePortfolioAssetIds(portfolioAssetIds?: Id<"imageAssets">[]) {
  const normalizedIds = portfolioAssetIds ?? [];
  if (normalizedIds.length > MAX_CATEGORY_PORTFOLIO_ASSETS) {
    throw new ConvexError(`Maximum ${MAX_CATEGORY_PORTFOLIO_ASSETS} portfolio images allowed`);
  }

  const uniqueAssetIds = new Set(normalizedIds.map((assetId) => String(assetId)));
  if (uniqueAssetIds.size !== normalizedIds.length) {
    throw new ConvexError("Portfolio image assets must be unique");
  }
}

function normalizeTaskerProfileLinks(label: string, links?: string[]) {
  const normalized = (links ?? [])
    .map((link) => link.trim())
    .filter((link) => link.length > 0);
  if (normalized.length > MAX_TASKER_PROFILE_LINKS) {
    throw new ConvexError(`Maximum ${MAX_TASKER_PROFILE_LINKS} ${label} links allowed`);
  }
  for (const link of normalized) {
    if (link.length > MAX_TASKER_PROFILE_LINK_LENGTH) {
      throw new ConvexError(`${label} links must be ${MAX_TASKER_PROFILE_LINK_LENGTH} characters or less`);
    }
  }
  return normalized;
}

function normalizeTaskerProfileLinkInput(args: {
  websiteLinks?: string[];
  socialLinks?: string[];
}) {
  return {
    websiteLinks: normalizeTaskerProfileLinks("website", args.websiteLinks),
    socialLinks: normalizeTaskerProfileLinks("social", args.socialLinks),
  };
}

function stringArraysEqual(left: string[], right: string[]) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

async function validateAndResolveCategoryPortfolio(
  ctx: any,
  userId: Id<"users">,
  portfolioAssetIds?: Id<"imageAssets">[],
  coverAssetId?: Id<"imageAssets">
) {
  const normalizedPortfolioAssetIds = portfolioAssetIds ?? [];
  validatePortfolioAssetIds(normalizedPortfolioAssetIds);

  if (coverAssetId && !normalizedPortfolioAssetIds.some((assetId) => assetId === coverAssetId)) {
    throw new ConvexError("coverAssetId must exist in portfolioAssetIds");
  }

  const portfolioAssets = await getOwnedImageAssets(
    ctx,
    normalizedPortfolioAssetIds,
    userId,
    "taskerCategoryPortfolio"
  );

  const normalizedCoverAssetId = coverAssetId ?? portfolioAssets[0]?._id;
  const compatibilityPhotos = toCompatibilityPhotos(portfolioAssets, normalizedCoverAssetId);

  return {
    normalizedPortfolioAssetIds,
    normalizedCoverAssetId,
    compatibilityPhotos,
  };
}

async function cleanupUnreferencedPortfolioAssets(
  ctx: any,
  userId: Id<"users">,
  portfolioAssetIds?: Id<"imageAssets">[]
) {
  const uniquePortfolioAssetIds = Array.from(
    new Map((portfolioAssetIds ?? []).map((assetId) => [String(assetId), assetId])).values()
  );

  await Promise.all(
    uniquePortfolioAssetIds.map((assetId) => deleteImageAssetIfUnreferenced(ctx, assetId, userId))
  );
}

async function loadOwnedTaskerProfile(ctx: any) {
  const { user } = await requireAppUser(ctx);
  const profile = await ctx.db
    .query("taskerProfiles")
    .withIndex("by_userId", (q: any) => q.eq("userId", user._id))
    .unique();

  if (!profile) {
    throw new ConvexError("Tasker profile not found");
  }

  return { user, profile };
}

async function buildTaskerProfileResponse(
  ctx: any,
  profile: any,
) {
  const user = await ctx.db.get(profile.userId);
  if (!user) {
    throw new ConvexError("User not found");
  }

  const photoSource: TaskerPhotoSource = profile.photoSource ?? "user";
  const photoImage = await getTaskerProfileImageAssetDto(ctx, user, profile, true);

  const taskerCategories = await ctx.db
    .query("taskerCategories")
    .withIndex("by_taskerProfile_category", (q: any) => q.eq("taskerProfileId", profile._id))
    .take(20);

  const categoriesWithNames = await Promise.all(
    taskerCategories.map(async (tc: any) => {
      const category = await ctx.db.get(tc.categoryId);
      const categoryImages = await getTaskerCategoryPortfolioImageDtos(ctx, tc, true);
      return {
        _id: tc._id,
        taskerProfileId: tc.taskerProfileId,
        userId: tc.userId,
        categoryId: tc.categoryId,
        bio: tc.bio,
        photos: tc.photos,
        portfolioAssetIds: tc.portfolioAssetIds,
        coverAssetId: categoryImages.coverAssetId,
        coverImage: categoryImages.coverImage,
        portfolioImages: categoryImages.portfolioImages,
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
    websiteLinks: profile.websiteLinks ?? [],
    socialLinks: profile.socialLinks ?? [],
    isOnboarded: profile.isOnboarded,
    rating: profile.rating,
    reviewCount: profile.reviewCount,
    completedJobs: profile.completedJobs,
    responseTime: profile.responseTime,
    verified: profile.verified,
    photoSource,
    photoAssetId: photoSource === "custom" ? profile.photoAssetId : undefined,
    photoImage,
    subscriptionPlan: profile.subscriptionPlan,
    subscriptionAccessType: profile.subscriptionAccessType,
    subscriptionTier: profile.subscriptionTier,
    premiumPin: buildPremiumPinView(profile),
    subscriptionActiveAccessTypes: profile.subscriptionActiveAccessTypes,
    subscriptionStatus: profile.subscriptionStatus,
    subscriptionEndsAt: profile.subscriptionEndsAt,
    ghostMode: profile.ghostMode,
    foundersBadge: profile.foundersBadge,
    location: profile.location,
    locationCheckedInAt: profile.locationCheckedInAt,
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
    websiteLinks: v.optional(v.array(v.string())),
    socialLinks: v.optional(v.array(v.string())),
    photoSource: v.optional(v.union(v.literal("user"), v.literal("custom"))),
    photoAssetId: v.optional(v.id("imageAssets")),
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    photos: v.optional(v.array(v.id("_storage"))),
    portfolioAssetIds: v.optional(v.array(v.id("imageAssets"))),
    coverAssetId: v.optional(v.id("imageAssets")),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  returns: v.id("taskerProfiles"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const existingProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .unique();

    if (existingProfile) {
      throw new ConvexError("Tasker profile already exists");
    }

    // Input validation
    if (args.displayName.length > 100) throw new ConvexError("Display name must be 100 characters or less");
    if (args.bio && args.bio.length > 2000) throw new ConvexError("Bio must be 2000 characters or less");
    const profileLinks = normalizeTaskerProfileLinkInput(args);
    if (args.categoryBio.length > MAX_CATEGORY_BIO_LENGTH) throw new ConvexError("Category bio must be 500 characters or less");
    if (args.serviceRadius < 1 || args.serviceRadius > 250) throw new ConvexError("Service radius must be between 1 and 250 km");
    if (args.hourlyRate !== undefined && (args.hourlyRate < 1 || args.hourlyRate > 100000000)) throw new ConvexError("Hourly rate must be between 1 and 1,000,000 (in cents)");
    if (args.fixedRate !== undefined && (args.fixedRate < 1 || args.fixedRate > 100000000)) throw new ConvexError("Fixed rate must be between 1 and 1,000,000 (in cents)");

    const photoSource = normalizeTaskerPhotoSource(args.photoSource, args.photoAssetId);
    if (photoSource === "user" && args.photoAssetId) {
      throw new ConvexError("photoAssetId requires photoSource=custom");
    }

    let customPhotoAssetId: Id<"imageAssets"> | undefined;
    if (photoSource === "custom") {
      if (!args.photoAssetId) {
        throw new ConvexError("photoAssetId is required when photoSource=custom");
      }
      const customPhotoAsset = await getOwnedImageAsset(ctx, args.photoAssetId, user._id, {
        purpose: "taskerPhoto",
        requireActive: true,
      });
      customPhotoAssetId = customPhotoAsset._id;
    }

    const portfolio = await validateAndResolveCategoryPortfolio(
      ctx,
      user._id,
      args.portfolioAssetIds,
      args.coverAssetId
    );

    const now = Date.now();

    const profileId = await ctx.db.insert("taskerProfiles", {
      userId: user._id,
      displayName: args.displayName,
      bio: args.bio,
      websiteLinks: profileLinks.websiteLinks,
      socialLinks: profileLinks.socialLinks,
      photoSource,
      photoAssetId: customPhotoAssetId,
      isOnboarded: true,
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      verified: false,
      subscriptionPlan: "none",
      subscriptionActiveAccessTypes: [],
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
      photos: portfolio.compatibilityPhotos.length > 0 ? portfolio.compatibilityPhotos : (args.photos ?? []),
      portfolioAssetIds: portfolio.normalizedPortfolioAssetIds,
      coverAssetId: portfolio.normalizedCoverAssetId,
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

    if (user.location.gpsCoordinates) {
      await ctx.runMutation(internal.location.syncTaskerGeo, {
        userId: user._id,
        lat: user.location.gpsCoordinates.lat,
        lng: user.location.gpsCoordinates.lng,
        checkedInAt: user.location.gpsCoordinates.checkedInAt,
      });
    }

    return profileId;
  },
});

export const getTaskerProfile = query({
  args: {},
  returns: v.union(taskerProfileResponseValidator, v.null()),
  handler: async (ctx) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;
    const { user } = session;

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .unique();

    if (!profile) return null;

    return buildTaskerProfileResponse(ctx, profile);
  },
});

export const updateTaskerProfile = mutation({
  args: {
    displayName: v.optional(v.string()),
    bio: v.optional(v.string()),
    websiteLinks: v.optional(v.array(v.string())),
    socialLinks: v.optional(v.array(v.string())),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const { profile } = await loadOwnedTaskerProfile(ctx);

    // Input validation
    if (args.displayName !== undefined && args.displayName.length > 100) throw new ConvexError("Display name must be 100 characters or less");
    if (args.bio !== undefined && args.bio.length > 2000) throw new ConvexError("Bio must be 2000 characters or less");
    const profileLinks = normalizeTaskerProfileLinkInput(args);

    const updates: any = {};

    if (args.displayName !== undefined && args.displayName !== profile.displayName) {
      updates.displayName = args.displayName;
    }

    if (args.bio !== undefined && args.bio !== profile.bio) {
      updates.bio = args.bio;
    }
    if (
      args.websiteLinks !== undefined &&
      !stringArraysEqual(profileLinks.websiteLinks, profile.websiteLinks ?? [])
    ) {
      updates.websiteLinks = profileLinks.websiteLinks;
    }
    if (
      args.socialLinks !== undefined &&
      !stringArraysEqual(profileLinks.socialLinks, profile.socialLinks ?? [])
    ) {
      updates.socialLinks = profileLinks.socialLinks;
    }

    if (Object.keys(updates).length > 0) {
      updates.updatedAt = Date.now();
      await ctx.db.patch(profile._id, updates);
    }

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      ...updates,
    });
  },
});

export const setTaskerPhoto = mutation({
  args: {
    photoSource: v.union(v.literal("user"), v.literal("custom")),
    photoAssetId: v.optional(v.id("imageAssets")),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const { user, profile } = await loadOwnedTaskerProfile(ctx);
    const previousCustomPhotoAssetId = profile.photoSource === "custom" ? profile.photoAssetId : undefined;

    if (args.photoSource === "user") {
      const updates = {
        photoSource: "user" as const,
        photoAssetId: undefined,
        updatedAt: Date.now(),
      };

      await ctx.db.patch(profile._id, updates);
      await deleteImageAssetIfUnreferenced(ctx, previousCustomPhotoAssetId, user._id);
      return buildTaskerProfileResponse(ctx, {
        ...profile,
        ...updates,
      });
    }

    if (!args.photoAssetId) {
      throw new ConvexError("photoAssetId is required when photoSource=custom");
    }

    const imageAsset = await getOwnedImageAsset(ctx, args.photoAssetId, user._id, {
      purpose: "taskerPhoto",
      requireActive: true,
    });

    const updates = {
      photoSource: "custom" as const,
      photoAssetId: imageAsset._id,
      updatedAt: Date.now(),
    };
    await ctx.db.patch(profile._id, updates);
    if (previousCustomPhotoAssetId && previousCustomPhotoAssetId !== imageAsset._id) {
      await deleteImageAssetIfUnreferenced(ctx, previousCustomPhotoAssetId, user._id);
    }

    return buildTaskerProfileResponse(ctx, {
      ...profile,
      ...updates,
    });
  },
});

export const setCategoryPortfolio = mutation({
  args: {
    categoryId: v.id("categories"),
    portfolioAssetIds: v.array(v.id("imageAssets")),
    coverAssetId: v.optional(v.id("imageAssets")),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const { user, profile } = await loadOwnedTaskerProfile(ctx);

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .unique();

    if (!category) {
      throw new ConvexError("Category not found");
    }

    const portfolio = await validateAndResolveCategoryPortfolio(
      ctx,
      user._id,
      args.portfolioAssetIds,
      args.coverAssetId
    );
    const previousPortfolioAssetIds = category.portfolioAssetIds ?? [];

    await ctx.db.patch(category._id, {
      portfolioAssetIds: portfolio.normalizedPortfolioAssetIds,
      coverAssetId: portfolio.normalizedCoverAssetId,
      photos: portfolio.compatibilityPhotos,
      updatedAt: Date.now(),
    });

    const nextPortfolioAssetIds = new Set(portfolio.normalizedPortfolioAssetIds.map(String));
    await Promise.all(
      previousPortfolioAssetIds
        .filter((assetId) => !nextPortfolioAssetIds.has(String(assetId)))
        .map((assetId) => deleteImageAssetIfUnreferenced(ctx, assetId, user._id))
    );

    return buildTaskerProfileResponse(ctx, profile);
  },
});

export const addTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
    categoryBio: v.string(),
    portfolioAssetIds: v.optional(v.array(v.id("imageAssets"))),
    coverAssetId: v.optional(v.id("imageAssets")),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const { user, profile } = await loadOwnedTaskerProfile(ctx);

    const existingCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .unique();

    if (existingCategory) {
      await cleanupUnreferencedPortfolioAssets(ctx, user._id, args.portfolioAssetIds);
      return null;
    }

    validateTaskerCategoryInput(args);
    const portfolio = await validateAndResolveCategoryPortfolio(
      ctx,
      user._id,
      args.portfolioAssetIds,
      args.coverAssetId
    );

    const now = Date.now();

    await ctx.db.insert("taskerCategories", {
      taskerProfileId: profile._id,
      userId: user._id,
      categoryId: args.categoryId,
      bio: args.categoryBio,
      photos: portfolio.compatibilityPhotos,
      portfolioAssetIds: portfolio.normalizedPortfolioAssetIds,
      coverAssetId: portfolio.normalizedCoverAssetId,
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
    portfolioAssetIds: v.optional(v.array(v.id("imageAssets"))),
    coverAssetId: v.optional(v.id("imageAssets")),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const { user, profile } = await loadOwnedTaskerProfile(ctx);

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .unique();

    if (!category) {
      throw new ConvexError("Category not found");
    }

    validateTaskerCategoryInput(args);

    const updates: {
      bio: string;
      rateType: "hourly" | "fixed";
      hourlyRate: number | undefined;
      fixedRate: number | undefined;
      serviceRadius: number;
      portfolioAssetIds?: Id<"imageAssets">[];
      coverAssetId?: Id<"imageAssets">;
      photos?: Id<"_storage">[];
      updatedAt: number;
    } = {
      bio: args.categoryBio,
      rateType: args.rateType,
      hourlyRate: args.rateType === "hourly" ? args.hourlyRate : undefined,
      fixedRate: args.rateType === "fixed" ? args.fixedRate : undefined,
      serviceRadius: args.serviceRadius,
      updatedAt: Date.now(),
    };
    const previousPortfolioAssetIds = category.portfolioAssetIds ?? [];

    if (args.portfolioAssetIds !== undefined || args.coverAssetId !== undefined) {
      const portfolio = await validateAndResolveCategoryPortfolio(
        ctx,
        user._id,
        args.portfolioAssetIds ?? previousPortfolioAssetIds,
        args.coverAssetId
      );
      updates.portfolioAssetIds = portfolio.normalizedPortfolioAssetIds;
      updates.coverAssetId = portfolio.normalizedCoverAssetId;
      updates.photos = portfolio.compatibilityPhotos;
    }

    await ctx.db.patch(category._id, updates);

    if (updates.portfolioAssetIds) {
      const nextPortfolioAssetIds = new Set(updates.portfolioAssetIds.map(String));
      await Promise.all(
        previousPortfolioAssetIds
          .filter((assetId) => !nextPortfolioAssetIds.has(String(assetId)))
          .map((assetId) => deleteImageAssetIfUnreferenced(ctx, assetId, user._id))
      );
    }

    return buildTaskerProfileResponse(ctx, profile);
  },
});

export const getTaskerById = query({
  args: { taskerId: v.id("taskerProfiles") },
  returns: v.union(taskerDetailValidator, v.null()),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    const includeUrls = !!session;

    const profile = await ctx.db.get(args.taskerId);
    if (!profile) return null;

    const user = await ctx.db.get(profile.userId);
    if (!user) return null;

    const userPhotoUrl = includeUrls && user.photo ? await ctx.storage.getUrl(user.photo) : null;
    const profileImage = await getTaskerProfileImageAssetDto(ctx, user, profile, includeUrls);

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) => q.eq("taskerProfileId", profile._id))
      .take(20);

    const categoriesWithNames = await Promise.all(
      taskerCategories.map(async (tc) => {
        const category = await ctx.db.get(tc.categoryId);
        const categoryImages = await getTaskerCategoryPortfolioImageDtos(ctx, tc, includeUrls);
        const firstPhotoStorageId = tc.photos?.[0];
        const firstPhotoUrl = includeUrls && firstPhotoStorageId
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
          coverAssetId: categoryImages.coverAssetId,
          coverImage: categoryImages.coverImage,
          portfolioImages: categoryImages.portfolioImages,
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
        const reviewerPhotoUrl = includeUrls && reviewer?.photo
          ? await ctx.storage.getUrl(reviewer.photo)
          : null;
        const reviewerImage = reviewer
          ? await getUserPhotoImageAssetDto(ctx, reviewer, includeUrls)
          : null;
        return {
          id: r._id,
          rating: r.rating,
          text: r.text,
          reviewerName: reviewer?.name ?? "Anonymous",
          reviewerPhotoUrl,
          reviewerImage,
          createdAt: r.createdAt,
        };
      })
    );
    const favourite = session
      ? await ctx.db
        .query("favouriteTaskers")
        .withIndex("by_seeker_tasker", (q) =>
          q.eq("seekerId", session.user._id).eq("taskerUserId", profile.userId)
        )
        .unique()
      : null;

    return {
      id: profile._id,
      userId: profile.userId,
      displayName: profile.displayName,
      bio: profile.bio,
      websiteLinks: profile.websiteLinks ?? [],
      socialLinks: profile.socialLinks ?? [],
      rating: profile.rating,
      reviewCount: profile.reviewCount,
      completedJobs: profile.completedJobs,
      verified: profile.verified,
      userName: user.name,
      userPhoto: user.photo,
      userPhotoUrl,
      profileImage,
      isFavourite: !!favourite,
      categories: categoriesWithNames,
      reviews: reviewsWithReviewers,
    };
  },
});

export const setFavouriteTasker = mutation({
  args: {
    taskerId: v.id("taskerProfiles"),
    isFavourite: v.boolean(),
  },
  returns: favouriteStatusValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    const profile = await ctx.db.get(args.taskerId);
    if (!profile || !profile.isOnboarded) {
      throw new ConvexError("Tasker profile not found");
    }
    if (profile.userId === user._id) {
      throw new ConvexError("You cannot favourite yourself");
    }

    const existing = await ctx.db
      .query("favouriteTaskers")
      .withIndex("by_seeker_tasker", (q) =>
        q.eq("seekerId", user._id).eq("taskerUserId", profile.userId)
      )
      .unique();

    if (args.isFavourite) {
      if (!existing) {
        const now = Date.now();
        await ctx.db.insert("favouriteTaskers", {
          seekerId: user._id,
          taskerUserId: profile.userId,
          createdAt: now,
          updatedAt: now,
        });
      }
      return { isFavourite: true };
    }

    if (existing) {
      await ctx.db.delete(existing._id);
    }
    return { isFavourite: false };
  },
});

export const listFavouriteTaskers = query({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.array(searchTaskerResultValidator),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return [];
    const { user } = session;

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .unique();

    if (!seekerProfile) return [];

    const limit = Math.max(1, Math.min(args.limit ?? DEFAULT_FAVOURITE_LIMIT, MAX_FAVOURITE_LIMIT));
    const favouriteRows = await ctx.db
      .query("favouriteTaskers")
      .withIndex("by_seeker_createdAt", (q) => q.eq("seekerId", user._id))
      .order("desc")
      .take(limit);
    const favouriteUserIds = favouriteRows.map((row) => row.taskerUserId);

    const results = await Promise.all(
      favouriteUserIds.map(async (favouriteUserId) => {
        const profile = await ctx.db
          .query("taskerProfiles")
          .withIndex("by_userId", (q) => q.eq("userId", favouriteUserId))
          .unique();

        if (!profile || !profile.isOnboarded) {
          return null;
        }

        const taskerUser = await ctx.db.get(profile.userId);
        if (!taskerUser) {
          return null;
        }

        const categoryData = await ctx.db
          .query("taskerCategories")
          .withIndex("by_taskerProfile_category", (q) => q.eq("taskerProfileId", profile._id))
          .first();

        if (!categoryData) {
          return null;
        }

        const category = await ctx.db.get(categoryData.categoryId);
        if (!category) {
          return null;
        }

        return await buildTaskerSummaryDto(ctx, {
          profile,
          user: taskerUser,
          category,
          categoryData,
          distance: "",
          completedJobs: profile.completedJobs,
          includeUrls: true,
        });
      })
    );

    return results.filter((result): result is NonNullable<typeof result> => result !== null);
  },
});

export const removeTaskerCategory = mutation({
  args: {
    categoryId: v.id("categories"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const { user, profile } = await loadOwnedTaskerProfile(ctx);

    const category = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id).eq("categoryId", args.categoryId)
      )
      .unique();

    if (!category) {
      throw new ConvexError("Category not found");
    }

    const removedPortfolioAssetIds = category.portfolioAssetIds ?? [];
    await ctx.db.delete(category._id);
    await Promise.all(
      removedPortfolioAssetIds.map((assetId) =>
        deleteImageAssetIfUnreferenced(ctx, assetId, user._id)
      )
    );

    return null;
  },
});

// Legacy compatibility for old clients. RevenueCat webhooks are the production source of truth.
export const updateSubscriptionPlan = mutation({
  args: {
    plan: v.literal("tasker"),
    accessType: v.optional(v.union(v.literal("subscription"), v.literal("lifetime"))),
    endsAt: v.optional(v.number()),
  },
  returns: taskerProfileResponseValidator,
  handler: async (_ctx, _args) => {
    throw new ConvexError("Direct billing activation is disabled. Tasker access is managed through RevenueCat webhooks.");
  },
});

// Legacy compatibility for old clients. RevenueCat webhooks are the production source of truth.
export const cancelSubscription = mutation({
  args: {},
  returns: taskerProfileResponseValidator,
  handler: async (_ctx) => {
    throw new ConvexError("Direct billing cancellation is disabled. Subscription state is managed through RevenueCat webhooks.");
  },
});

export const getCurrentUserIdForRevenueCatReconciliation = internalQuery({
  args: {},
  returns: v.union(v.id("users"), v.null()),
  handler: async (ctx) => {
    const session = await getAppUserOrNull(ctx);
    return session?.user._id ?? null;
  },
});

export const getCurrentTaskerProfileForRevenueCatReconciliation = internalQuery({
  args: {},
  returns: v.union(taskerProfileResponseValidator, v.null()),
  handler: async (ctx) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", session.user._id))
      .unique();

    if (!profile) return null;
    return await buildTaskerProfileResponse(ctx, profile);
  },
});

export const reconcileRevenueCatSubscription = action({
  args: {},
  returns: v.union(taskerProfileResponseValidator, v.null()),
  handler: async (ctx) => {
    const currentUserId = await ctx.runQuery(internal.taskers.getCurrentUserIdForRevenueCatReconciliation, {});
    if (!currentUserId) {
      throw new ConvexError("Unauthorized");
    }

    await ctx.runAction(internal.taskersInternal.reconcileRevenueCatCustomer, {
      candidateAppUserIds: [String(currentUserId)],
      source: "client_manual_reconciliation",
    });

    return await ctx.runQuery(internal.taskers.getCurrentTaskerProfileForRevenueCatReconciliation, {});
  },
});

export const setGhostMode = mutation({
  args: {
    ghostMode: v.boolean(),
  },
  returns: taskerProfileResponseValidator,
  handler: async (ctx, args) => {
    const { profile } = await loadOwnedTaskerProfile(ctx);

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
