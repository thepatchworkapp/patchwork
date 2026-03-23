import { components } from "./_generated/api";
import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { getReviewAccessStatus, setReviewAccessEnabled } from "./reviewAccess";
import { taskerGeo } from "./geospatial";

function getAdminEmailAllowlist(): Set<string> {
  // Support both ADMIN_EMAILS (comma-separated) and legacy ADMIN_EMAIL (single).
  const raw =
    process.env.ADMIN_EMAILS ||
    process.env.ADMIN_EMAIL ||
    "";
  const emails = raw
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return new Set(emails);
}

const ADMIN_EMAILS = getAdminEmailAllowlist();
const RESET_BATCH_SIZE = 128;

async function deleteStorageIds(ctx: any, storageIds: Set<any>) {
  let deleted = 0;
  for (const storageId of storageIds) {
    try {
      await ctx.storage.delete(storageId);
      deleted += 1;
    } catch {
      // Ignore missing blobs so a partially cleaned environment can still reset.
    }
  }
  return deleted;
}

async function deleteTableRows(
  ctx: any,
  tableName: string,
  onRow?: (row: any) => Promise<void> | void
) {
  let deleted = 0;

  while (true) {
    const rows = await (ctx.db as any).query(tableName).take(RESET_BATCH_SIZE);
    if (!rows.length) {
      break;
    }

    for (const row of rows) {
      if (onRow) {
        await onRow(row);
      }
      await ctx.db.delete(row._id);
      deleted += 1;
    }
  }

  return deleted;
}

async function resetBetterAuthNonAdmin(ctx: any) {
  const adminAuthUserIds = new Set<string>();

  for (const email of ADMIN_EMAILS) {
    const authUser = await ctx.runQuery(components.betterAuth.adapter.findOne, {
      model: "user",
      where: [{ field: "email", operator: "eq", value: email }],
    });

    const authUserId = authUser ? String(authUser.id ?? authUser._id ?? "") : "";
    if (authUserId) {
      adminAuthUserIds.add(authUserId);
    }
  }

  const nonAdminUserFilter = ADMIN_EMAILS.size
    ? [{ field: "email", operator: "not_in" as const, value: Array.from(ADMIN_EMAILS) }]
    : undefined;
  const nonAdminAuthIdFilter = adminAuthUserIds.size
    ? [{ field: "userId", operator: "not_in" as const, value: Array.from(adminAuthUserIds) }]
    : undefined;

  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "session", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "account", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "twoFactor", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "passkey", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "oauthAccessToken", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "oauthConsent", where: nonAdminAuthIdFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "verification" },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
  await ctx.runMutation(components.betterAuth.adapter.deleteMany, {
    input: { model: "user", where: nonAdminUserFilter },
    paginationOpts: { cursor: null, numItems: 10_000 },
  });
}

async function requireAdmin(ctx: any): Promise<boolean> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) return false;
  return ADMIN_EMAILS.has((identity.email || "").toLowerCase());
}

async function requireAdminOrThrow(ctx: any) {
  if (!(await requireAdmin(ctx))) {
    throw new ConvexError("Unauthorized");
  }
}

export const listAllUsers = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    if (!(await requireAdmin(ctx))) {
      return { users: [], cursor: null };
    }

    const limit = args.limit ?? 50;
    const query_obj = ctx.db.query("users").order("desc");

    const getUsersBeforeCursor = async (cursor: string) => {
      return await query_obj
        .filter((q) => q.lt(q.field("_creationTime"), Number(cursor)))
        .take(limit + 1);
    };

    const users =
      args.cursor !== undefined
        ? await getUsersBeforeCursor(args.cursor)
        : await query_obj.take(limit + 1);

    const hasMore = users.length > limit;
    const result = hasMore ? users.slice(0, limit) : users;
    const nextCursor = hasMore ? result[result.length - 1]._creationTime.toString() : null;

    return {
      users: await Promise.all(
        result.map(async (user) => {
          const photoUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;
          return {
            _id: user._id,
            email: user.email,
            name: user.name,
            photo: user.photo,
            photoUrl,
            location: user.location,
            roles: user.roles,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          };
        })
      ),
      cursor: nextCursor,
    };
  },
});

export const isAdmin = query({
  args: {},
  handler: async (ctx) => {
    return await requireAdmin(ctx);
  },
});

export const getReviewAccess = query({
  args: {},
  handler: async (ctx) => {
    if (!(await requireAdmin(ctx))) return null;
    return await getReviewAccessStatus(ctx);
  },
});

export const setReviewAccess = mutation({
  args: {
    enabled: v.boolean(),
  },
  handler: async (ctx, args) => {
    await requireAdminOrThrow(ctx);
    return await setReviewAccessEnabled(ctx, args.enabled);
  },
});

export const reseedReviewerAccounts = mutation({
  args: {},
  handler: async (ctx) => {
    await requireAdminOrThrow(ctx);
    return await setReviewAccessEnabled(ctx, true);
  },
});

export const resetDatabase = mutation({
  args: {},
  handler: async (ctx) => {
    await requireAdminOrThrow(ctx);

    const storageIds = new Set<any>();

    const deletedMessages = await deleteTableRows(ctx, "messages", async (message) => {
      for (const attachment of message.attachments ?? []) {
        storageIds.add(attachment);
      }
    });
    const deletedReviews = await deleteTableRows(ctx, "reviews");
    const deletedJobs = await deleteTableRows(ctx, "jobs");
    const deletedProposals = await deleteTableRows(ctx, "proposals");
    const deletedConversations = await deleteTableRows(ctx, "conversations");
    const deletedJobRequests = await deleteTableRows(ctx, "jobRequests", async (jobRequest) => {
      for (const photo of jobRequest.photos ?? []) {
        storageIds.add(photo);
      }
    });
    const deletedTaskerCategories = await deleteTableRows(ctx, "taskerCategories", async (taskerCategory) => {
      for (const photo of taskerCategory.photos ?? []) {
        storageIds.add(photo);
      }
    });
    const deletedTaskerProfiles = await deleteTableRows(ctx, "taskerProfiles", async (taskerProfile) => {
      await taskerGeo.remove(ctx, taskerProfile._id);
    });
    const deletedSeekerProfiles = await deleteTableRows(ctx, "seekerProfiles");
    const deletedReviewAccess = await deleteTableRows(ctx, "reviewAccess");
    const deletedOtps = await deleteTableRows(ctx, "otps");
    const deletedAdminOtps = await deleteTableRows(ctx, "adminOtps");
    const deletedUsers = await deleteTableRows(ctx, "users", async (user) => {
      if (user.photo) {
        storageIds.add(user.photo);
      }
    });

    const deletedStorageFiles = await deleteStorageIds(ctx, storageIds);
    await resetBetterAuthNonAdmin(ctx);

    return {
      resetAt: Date.now(),
      deletedMessages,
      deletedReviews,
      deletedJobs,
      deletedProposals,
      deletedConversations,
      deletedJobRequests,
      deletedTaskerCategories,
      deletedTaskerProfiles,
      deletedSeekerProfiles,
      deletedReviewAccess,
      deletedOtps,
      deletedAdminOtps,
      deletedUsers,
      deletedStorageFiles,
      preservedAdminEmails: Array.from(ADMIN_EMAILS),
    };
  },
});

export const getUserDetail = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    if (!(await requireAdmin(ctx))) return null;

    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const userPhotoUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    let taskerProfileWithCategories = null;
    if (taskerProfile) {
      const taskerCategories = await ctx.db
        .query("taskerCategories")
        .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", taskerProfile._id))
        .take(50);

      const categoriesWithNames = await Promise.all(
        taskerCategories.map(async (tc) => {
          const category = await ctx.db.get(tc.categoryId);
          const photoUrls = await Promise.all(
            // Schema caps this at 10; keep admin UI complete but bounded.
            (tc.photos ?? []).slice(0, 10).map(async (storageId) => (await ctx.storage.getUrl(storageId)) || null)
          );
          return {
            ...tc,
            categoryName: category?.name ?? "Unknown",
            categorySlug: category?.slug ?? "unknown",
            photoUrls: photoUrls.filter((u): u is string => !!u),
          };
        })
      );

      taskerProfileWithCategories = {
        ...taskerProfile,
        categories: categoriesWithNames,
      };
    }

    const jobsAsSeeker = await ctx.db
      .query("jobs")
      .withIndex("by_seeker", (q) => q.eq("seekerId", args.userId))
      .order("desc")
      .take(20);

    const jobsAsTasker = await ctx.db
      .query("jobs")
      .withIndex("by_tasker", (q) => q.eq("taskerId", args.userId))
      .order("desc")
      .take(20);

    const reviewsGiven = await ctx.db
      .query("reviews")
      .withIndex("by_reviewer", (q) => q.eq("reviewerId", args.userId))
      .order("desc")
      .take(20);

    const reviewsReceived = await ctx.db
      .query("reviews")
      .withIndex("by_reviewee", (q) => q.eq("revieweeId", args.userId))
      .order("desc")
      .take(20);

    const reviewsGivenEnriched = await Promise.all(
      reviewsGiven.map(async (r) => {
        const reviewee = await ctx.db.get(r.revieweeId);
        return {
          ...r,
          revieweeName: reviewee?.name ?? "Unknown",
        };
      })
    );

    const reviewsReceivedEnriched = await Promise.all(
      reviewsReceived.map(async (r) => {
        const reviewer = await ctx.db.get(r.reviewerId);
        return {
          ...r,
          reviewerName: reviewer?.name ?? "Unknown",
        };
      })
    );

    return {
      user,
      userPhotoUrl,
      seekerProfile: seekerProfile ?? null,
      taskerProfile: taskerProfileWithCategories,
      jobsAsSeeker,
      jobsAsTasker,
      reviewsGiven: reviewsGivenEnriched,
      reviewsReceived: reviewsReceivedEnriched,
    };
  },
});
