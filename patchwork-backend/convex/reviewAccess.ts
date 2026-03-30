import { ConvexError } from "convex/values";
import { internal } from "./_generated/api";

export const APP_REVIEW_EMAIL = "review@apple.com";
export const APP_REVIEW_SEEKER_EMAIL = "seeker@apple.com";

const REVIEW_NAME = "Apple App Review";
const REVIEW_SEEKER_NAME = "Apple Seeker Review";
const REVIEW_DISPLAY_NAME = "Patchwork Review Account";
const REVIEW_CITY = "Toronto";
const REVIEW_PROVINCE = "Ontario";
const REVIEW_LAT = 43.6532;
const REVIEW_LNG = -79.3832;
const REVIEW_CATEGORY_NAME = "Cleaning";
const REVIEW_CATEGORY_SLUG = "cleaning";
const REVIEW_RATE_CENTS = 6500;
const REVIEW_SERVICE_RADIUS_KM = 25;
const PRIMARY_REVIEW_EMAIL = APP_REVIEW_EMAIL;

type ReviewAccessMode = "fullProfile" | "authOnly";

type ReviewAccessConfig = {
  email: string;
  name: string;
  mode: ReviewAccessMode;
};

const REVIEW_ACCESS_CONFIGS: Record<string, ReviewAccessConfig> = {
  [APP_REVIEW_EMAIL]: {
    email: APP_REVIEW_EMAIL,
    name: REVIEW_NAME,
    mode: "fullProfile",
  },
  [APP_REVIEW_SEEKER_EMAIL]: {
    email: APP_REVIEW_SEEKER_EMAIL,
    name: REVIEW_SEEKER_NAME,
    mode: "authOnly",
  },
};

const REVIEW_ACCESS_EMAILS = Object.keys(REVIEW_ACCESS_CONFIGS);

function reviewAuthIdForUserId(userId: string): string {
  const issuer = process.env.CONVEX_SITE_URL;
  if (!issuer) {
    throw new ConvexError("CONVEX_SITE_URL is not configured");
  }
  return `${issuer}|${userId}`;
}

function makeSessionToken(): string {
  return `${crypto.randomUUID().replace(/-/g, "")}${crypto.randomUUID().replace(/-/g, "")}`;
}

function getReviewAccessConfig(email: string): ReviewAccessConfig {
  const config = REVIEW_ACCESS_CONFIGS[email];
  if (!config) {
    throw new ConvexError("Unknown review account");
  }
  return config;
}

async function getReviewAccessRecord(ctx: any, email: string = PRIMARY_REVIEW_EMAIL) {
  return await ctx.db
    .query("reviewAccess")
    .withIndex("by_email", (q: any) => q.eq("email", email))
    .unique();
}

async function upsertReviewAccessRecord(
  ctx: any,
  email: string,
  patch: {
    enabled: boolean;
    betterAuthUserId?: string;
    appUserId?: any;
    lastEnabledAt?: number;
    lastDisabledAt?: number;
  }
) {
  const existing = await getReviewAccessRecord(ctx, email);
  const next = {
    email,
    enabled: patch.enabled,
    updatedAt: Date.now(),
    ...(patch.betterAuthUserId !== undefined ? { betterAuthUserId: patch.betterAuthUserId } : {}),
    ...(patch.appUserId !== undefined ? { appUserId: patch.appUserId } : {}),
    ...(patch.lastEnabledAt !== undefined ? { lastEnabledAt: patch.lastEnabledAt } : {}),
    ...(patch.lastDisabledAt !== undefined ? { lastDisabledAt: patch.lastDisabledAt } : {}),
  };

  if (existing) {
    await ctx.db.patch(existing._id, next);
    return await ctx.db.get(existing._id);
  }

  const id = await ctx.db.insert("reviewAccess", next);
  return await ctx.db.get(id);
}

async function ensureReviewCategory(ctx: any) {
  let category = await ctx.db
    .query("categories")
    .withIndex("by_slug", (q: any) => q.eq("slug", REVIEW_CATEGORY_SLUG))
    .unique();

  if (!category) {
    const categoryId = await ctx.db.insert("categories", {
      name: REVIEW_CATEGORY_NAME,
      slug: REVIEW_CATEGORY_SLUG,
      emoji: "🧹",
      group: "Home Services",
      isActive: true,
      sortOrder: 48,
    });
    category = await ctx.db.get(categoryId);
  }

  if (!category) {
    throw new ConvexError("Review category could not be created");
  }

  return category;
}

async function ensureAppReviewUser(ctx: any, betterAuthUserId?: string | null) {
  const now = Date.now();
  let user = await ctx.db
    .query("users")
    .withIndex("by_email", (q: any) => q.eq("email", APP_REVIEW_EMAIL))
    .unique();
  const authId =
    betterAuthUserId != null
      ? reviewAuthIdForUserId(betterAuthUserId)
      : user?.authId ?? "app-review-pending-auth";

  const basePatch = {
    authId,
    email: APP_REVIEW_EMAIL,
    emailVerified: true,
    name: REVIEW_NAME,
    location: {
      city: REVIEW_CITY,
      province: REVIEW_PROVINCE,
      coordinates: {
        lat: REVIEW_LAT,
        lng: REVIEW_LNG,
      },
    },
    roles: {
      isSeeker: true,
      isTasker: true,
    },
    settings: {
      notificationsEnabled: true,
      locationEnabled: true,
    },
    updatedAt: now,
  };

  if (!user) {
    const userId = await ctx.db.insert("users", {
      ...basePatch,
      createdAt: now,
    });
    user = await ctx.db.get(userId);
  } else {
    await ctx.db.patch(user._id, basePatch);
    user = await ctx.db.get(user._id);
  }

  if (!user) {
    throw new ConvexError("Review app user could not be created");
  }

  return user;
}

async function ensureSeekerProfile(ctx: any, userId: any) {
  const existing = await ctx.db
    .query("seekerProfiles")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .unique();

  if (existing) {
    return existing;
  }

  const seekerProfileId = await ctx.db.insert("seekerProfiles", {
    userId,
    jobsPosted: 0,
    completedJobs: 0,
    rating: 5,
    ratingCount: 1,
    favouriteTaskers: [],
    updatedAt: Date.now(),
  });

  return await ctx.db.get(seekerProfileId);
}

async function ensureTaskerProfile(ctx: any, userId: any, categoryId: any) {
  const now = Date.now();

  let taskerProfile = await ctx.db
    .query("taskerProfiles")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .unique();

  const taskerPatch = {
    displayName: REVIEW_DISPLAY_NAME,
    bio: "Patchwork account prepared for Apple App Review. Includes both seeker and tasker access.",
    isOnboarded: true,
    rating: 5,
    reviewCount: 1,
    completedJobs: 3,
    responseTime: "< 1 hour",
    verified: true,
    subscriptionPlan: "tasker" as const,
    subscriptionAccessType: "lifetime" as const,
    subscriptionStatus: "active" as const,
    subscriptionEndsAt: undefined,
    ghostMode: false,
    foundersBadge: {
      categoryId,
      awardedAt: now,
    },
    location: {
      lat: REVIEW_LAT,
      lng: REVIEW_LNG,
    },
    updatedAt: now,
  };

  if (!taskerProfile) {
    const taskerProfileId = await ctx.db.insert("taskerProfiles", {
      userId,
      ...taskerPatch,
      createdAt: now,
    });
    taskerProfile = await ctx.db.get(taskerProfileId);
  } else {
    await ctx.db.patch(taskerProfile._id, taskerPatch);
    taskerProfile = await ctx.db.get(taskerProfile._id);
  }

  if (!taskerProfile) {
    throw new ConvexError("Review tasker profile could not be created");
  }

  let taskerCategory = await ctx.db
    .query("taskerCategories")
    .withIndex("by_taskerProfile_category", (q: any) =>
      q.eq("taskerProfileId", taskerProfile._id).eq("categoryId", categoryId)
    )
    .unique();

  const taskerCategoryPatch = {
    taskerProfileId: taskerProfile._id,
    userId,
    categoryId,
    bio: "Reliable help for cleaning, organizing, and light home resets.",
    photos: [],
    rateType: "hourly" as const,
    hourlyRate: REVIEW_RATE_CENTS,
    fixedRate: undefined,
    serviceRadius: REVIEW_SERVICE_RADIUS_KM,
    rating: 5,
    reviewCount: 1,
    completedJobs: 3,
    updatedAt: now,
  };

  if (!taskerCategory) {
    const taskerCategoryId = await ctx.db.insert("taskerCategories", {
      ...taskerCategoryPatch,
      createdAt: now,
    });
    taskerCategory = await ctx.db.get(taskerCategoryId);
  } else {
    await ctx.db.patch(taskerCategory._id, taskerCategoryPatch);
    taskerCategory = await ctx.db.get(taskerCategory._id);
  }

  if (!taskerCategory) {
    throw new ConvexError("Review tasker category could not be created");
  }

  await ctx.scheduler.runAfter(0, internal.location.syncTaskerGeo, {
    userId,
    lat: REVIEW_LAT,
    lng: REVIEW_LNG,
  });

  return { taskerProfile, taskerCategory };
}

export async function ensureReviewAccount(
  ctx: any,
  email: string = APP_REVIEW_EMAIL,
  betterAuthUserId?: string | null
) {
  const config = getReviewAccessConfig(email);
  if (config.mode !== "fullProfile") {
    return {
      betterAuthUserId: betterAuthUserId ?? null,
      appUserId: undefined,
      taskerProfileId: null,
      taskerCategoryId: null,
    };
  }

  const category = await ensureReviewCategory(ctx);
  const appUser = await ensureAppReviewUser(ctx, betterAuthUserId);
  await ensureSeekerProfile(ctx, appUser._id);
  const { taskerProfile, taskerCategory } = await ensureTaskerProfile(
    ctx,
    appUser._id,
    category._id
  );

  return {
    betterAuthUserId: betterAuthUserId ?? null,
    appUserId: appUser._id,
    taskerProfileId: taskerProfile._id,
    taskerCategoryId: taskerCategory._id,
  };
}

export async function getReviewAccessStatus(ctx: any) {
  const record = await getReviewAccessRecord(ctx, PRIMARY_REVIEW_EMAIL);

  return {
    email: PRIMARY_REVIEW_EMAIL,
    allowedEmails: REVIEW_ACCESS_EMAILS,
    enabled: record?.enabled ?? false,
    betterAuthUserId: record?.betterAuthUserId ?? null,
    appUserId: record?.appUserId ?? null,
    lastEnabledAt: record?.lastEnabledAt ?? null,
    lastDisabledAt: record?.lastDisabledAt ?? null,
    updatedAt: record?.updatedAt ?? null,
  };
}

async function setSingleReviewAccessEnabled(
  ctx: any,
  email: string,
  enabled: boolean,
  betterAuthUserId?: string | null
) {
  const config = getReviewAccessConfig(email);
  const now = Date.now();
  const existing = await getReviewAccessRecord(ctx, email);

  if (enabled) {
    const seeded =
      config.mode === "fullProfile"
        ? await ensureReviewAccount(ctx, email, betterAuthUserId ?? existing?.betterAuthUserId)
        : {
            betterAuthUserId: betterAuthUserId ?? existing?.betterAuthUserId ?? null,
            appUserId: existing?.appUserId,
            taskerProfileId: null,
            taskerCategoryId: null,
          };
    const record = await upsertReviewAccessRecord(ctx, email, {
      enabled: true,
      betterAuthUserId: betterAuthUserId ?? existing?.betterAuthUserId,
      appUserId: seeded.appUserId,
      lastEnabledAt: existing?.lastEnabledAt ?? now,
      lastDisabledAt: existing?.lastDisabledAt,
    });

    return {
      email: config.email,
      enabled: true,
      betterAuthUserId:
        record?.betterAuthUserId ??
        betterAuthUserId ??
        existing?.betterAuthUserId ??
        null,
      appUserId: record?.appUserId ?? seeded.appUserId,
      updatedAt: record?.updatedAt ?? now,
      lastEnabledAt: record?.lastEnabledAt ?? existing?.lastEnabledAt ?? now,
      lastDisabledAt: record?.lastDisabledAt ?? existing?.lastDisabledAt ?? null,
    };
  }

  const record = await upsertReviewAccessRecord(ctx, email, {
    enabled: false,
    betterAuthUserId: betterAuthUserId ?? existing?.betterAuthUserId,
    appUserId: existing?.appUserId,
    lastEnabledAt: existing?.lastEnabledAt,
    lastDisabledAt: now,
  });

  return {
    email: config.email,
    enabled: false,
    betterAuthUserId:
      record?.betterAuthUserId ??
      betterAuthUserId ??
      existing?.betterAuthUserId ??
      null,
    appUserId: record?.appUserId ?? existing?.appUserId ?? null,
    updatedAt: record?.updatedAt ?? now,
    lastEnabledAt: record?.lastEnabledAt ?? existing?.lastEnabledAt ?? null,
    lastDisabledAt: record?.lastDisabledAt ?? now,
  };
}

export async function setReviewAccessEnabled(
  ctx: any,
  enabled: boolean,
  betterAuthUserId?: string | null,
  email?: string | null
) {
  if (email) {
    return await setSingleReviewAccessEnabled(ctx, email, enabled, betterAuthUserId);
  }

  const primary = await setSingleReviewAccessEnabled(
    ctx,
    PRIMARY_REVIEW_EMAIL,
    enabled,
    betterAuthUserId
  );

  for (const reviewEmail of REVIEW_ACCESS_EMAILS) {
    if (reviewEmail === PRIMARY_REVIEW_EMAIL) {
      continue;
    }
    await setSingleReviewAccessEnabled(ctx, reviewEmail, enabled);
  }

  return {
    ...primary,
    allowedEmails: REVIEW_ACCESS_EMAILS,
  };
}

export async function createReviewSession(ctx: any, email: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const config = getReviewAccessConfig(normalizedEmail);

  const status = await getReviewAccessRecord(ctx, config.email);
  if (!status?.enabled) {
    throw new ConvexError("App review access is disabled");
  }

  const sessionToken = makeSessionToken();
  const authSession = await ctx.runMutation(internal.reviewAccessInternal.ensureReviewAuthSession, {
    email: config.email,
    name: config.name,
    sessionToken,
    userAgent: "Patchwork App Review",
  });

  const betterAuthUserId = String(authSession?.betterAuthUserId ?? "");
  if (!betterAuthUserId) {
    throw new ConvexError("Review auth user could not be created");
  }

  const seeded = await ctx.runMutation(internal.reviewAccessInternal.bootstrap, {
    enabled: true,
    betterAuthUserId,
    email: config.email,
  });

  return {
    email: config.email,
    sessionToken,
    appUserId: seeded.appUserId ?? null,
  };
}
