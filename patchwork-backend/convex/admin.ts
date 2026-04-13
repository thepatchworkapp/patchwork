import { action, internalMutation, mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { authComponent } from "./auth";
import { getReviewAccessStatus, setReviewAccessEnabled } from "./reviewAccess";
import { taskerGeo } from "./geospatial";
import { internal } from "./_generated/api";

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
const REVENUECAT_SUBSCRIBER_API_BASE_URL = "https://api.revenuecat.com/v1/subscribers";
const reviewAccessStatusValidator = v.object({
  email: v.string(),
  allowedEmails: v.array(v.string()),
  enabled: v.boolean(),
  betterAuthUserId: v.union(v.string(), v.null()),
  appUserId: v.union(v.id("users"), v.null()),
  lastEnabledAt: v.union(v.number(), v.null()),
  lastDisabledAt: v.union(v.number(), v.null()),
  updatedAt: v.union(v.number(), v.null()),
});
const feedbackSubmissionAdminValidator = v.object({
  _id: v.id("feedbackSubmissions"),
  _creationTime: v.number(),
  userId: v.id("users"),
  userName: v.string(),
  userEmail: v.union(v.string(), v.null()),
  message: v.string(),
  createdAt: v.number(),
  updatedAt: v.number(),
});

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

async function collectStorageIdsForRows(
  rows: Array<any>,
  storageIds: Set<any>,
  getStorageIds: (row: any) => Array<any>
) {
  for (const row of rows) {
    for (const storageId of getStorageIds(row)) {
      storageIds.add(storageId);
    }
  }
}

async function resetApplicationData(ctx: any) {
  const storageIds = new Set<any>();
  const deletedUserAppUserIds: string[] = [];

  const deletedMessages = await deleteTableRows(ctx, "messages", async (message) => {
    await collectStorageIdsForRows([message], storageIds, (row) => row.attachments ?? []);
  });
  const deletedReviews = await deleteTableRows(ctx, "reviews");
  const deletedJobs = await deleteTableRows(ctx, "jobs");
  const deletedProposals = await deleteTableRows(ctx, "proposals");
  const deletedConversations = await deleteTableRows(ctx, "conversations");
  const deletedJobRequests = await deleteTableRows(ctx, "jobRequests", async (jobRequest) => {
    await collectStorageIdsForRows([jobRequest], storageIds, (row) => row.photos ?? []);
  });
  const deletedTaskerCategories = await deleteTableRows(ctx, "taskerCategories", async (taskerCategory) => {
    await collectStorageIdsForRows([taskerCategory], storageIds, (row) => row.photos ?? []);
  });
  const deletedTaskerProfiles = await deleteTableRows(ctx, "taskerProfiles", async (taskerProfile) => {
    await taskerGeo.remove(ctx, taskerProfile._id);
  });
  const deletedSeekerProfiles = await deleteTableRows(ctx, "seekerProfiles");
  const deletedFeedbackSubmissions = await deleteTableRows(ctx, "feedbackSubmissions");
  const deletedReviewAccess = await deleteTableRows(ctx, "reviewAccess");
  const deletedOtps = await deleteTableRows(ctx, "otps");
  const deletedAdminOtps = await deleteTableRows(ctx, "adminOtps");
  const deletedUsers = await deleteTableRows(ctx, "users", async (user) => {
    deletedUserAppUserIds.push(String(user._id));
    if (user.photo) {
      storageIds.add(user.photo);
    }
  });

  const deletedStorageFiles = await deleteStorageIds(ctx, storageIds);

  return {
    deletedMessages,
    deletedReviews,
    deletedJobs,
    deletedProposals,
    deletedConversations,
    deletedJobRequests,
    deletedTaskerCategories,
    deletedTaskerProfiles,
    deletedSeekerProfiles,
    deletedFeedbackSubmissions,
    deletedReviewAccess,
    deletedOtps,
    deletedAdminOtps,
    deletedUsers,
    deletedStorageFiles,
    deletedUserAppUserIds,
  };
}

async function performDatabaseReset(ctx: any) {
  await resetBetterAuthNonAdmin(ctx);
  const resetCounts = await resetApplicationData(ctx);

  return {
    resetAt: Date.now(),
    ...resetCounts,
    preservedAdminEmails: Array.from(ADMIN_EMAILS),
  };
}

type RevenueCatCleanupSummary = {
  status: "completed" | "partial" | "skipped";
  attemptedCustomers: number;
  deletedCustomers: number;
  missingCustomers: number;
  failedCustomers: number;
  message: string;
};

async function deleteRevenueCatCustomer(appUserId: string, secretApiKey: string) {
  const response = await fetch(
    `${REVENUECAT_SUBSCRIBER_API_BASE_URL}/${encodeURIComponent(appUserId)}`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${secretApiKey}`,
      },
    },
  );

  if (response.ok) {
    return "deleted" as const;
  }

  if (response.status === 404) {
    return "missing" as const;
  }

  const responseText = await response.text();
  throw new Error(
    `RevenueCat delete failed for ${appUserId} (${response.status}): ${responseText || "No response body"}`
  );
}

async function clearRevenueCatCustomers(appUserIds: string[]): Promise<RevenueCatCleanupSummary> {
  const secretApiKey = process.env.REVENUECAT_SECRET_API_KEY;
  const uniqueAppUserIds = Array.from(new Set(appUserIds.filter(Boolean)));

  if (!uniqueAppUserIds.length) {
    return {
      status: "completed",
      attemptedCustomers: 0,
      deletedCustomers: 0,
      missingCustomers: 0,
      failedCustomers: 0,
      message: "No app users were present, so no RevenueCat customers needed cleanup.",
    };
  }

  if (!secretApiKey) {
    return {
      status: "skipped",
      attemptedCustomers: uniqueAppUserIds.length,
      deletedCustomers: 0,
      missingCustomers: 0,
      failedCustomers: uniqueAppUserIds.length,
      message: "RevenueCat cleanup skipped because REVENUECAT_SECRET_API_KEY is not configured.",
    };
  }

  let deletedCustomers = 0;
  let missingCustomers = 0;
  let failedCustomers = 0;

  for (const appUserId of uniqueAppUserIds) {
    try {
      const result = await deleteRevenueCatCustomer(appUserId, secretApiKey);
      if (result === "deleted") {
        deletedCustomers += 1;
      } else {
        missingCustomers += 1;
      }
    } catch (error) {
      failedCustomers += 1;
      console.error("[AdminReset] RevenueCat cleanup failed", {
        appUserId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  const status = failedCustomers > 0 ? "partial" : "completed";
  const message =
    status === "completed"
      ? `RevenueCat cleanup deleted ${deletedCustomers} customer(s) and skipped ${missingCustomers} missing record(s).`
      : `RevenueCat cleanup deleted ${deletedCustomers} customer(s), skipped ${missingCustomers} missing record(s), and hit ${failedCustomers} failure(s).`;

  return {
    status,
    attemptedCustomers: uniqueAppUserIds.length,
    deletedCustomers,
    missingCustomers,
    failedCustomers,
    message,
  };
}

async function resetBetterAuthNonAdmin(ctx: any) {
  const authAdapter = await authComponent.adapter(ctx)({});
  const adminAuthUserIds = new Set<string>();

  const adminAuthUsers = await Promise.all(
    Array.from(ADMIN_EMAILS).map(async (email) =>
      await authAdapter.findOne({
        model: "user",
        where: [{ field: "email", operator: "eq", value: email }],
      })
    )
  );

  for (const authUser of adminAuthUsers) {
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

  const deleteAuthModelIfPresent = async (model: string, where?: Array<any>) => {
    try {
      await authAdapter.deleteMany({
        model,
        where,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.includes(`Model "${model}" not found in schema`)) {
        return;
      }
      throw error;
    }
  };

  await Promise.all([
    deleteAuthModelIfPresent("session", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("account", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("twoFactor", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("passkey", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("oauthAccessToken", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("oauthConsent", nonAdminAuthIdFilter),
    deleteAuthModelIfPresent("verification"),
    deleteAuthModelIfPresent("user", nonAdminUserFilter),
  ]);
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

async function enrichFeedbackSubmission(ctx: any, submission: any) {
  const user = await ctx.db.get(submission.userId);
  return {
    ...submission,
    userName: user?.name ?? "Unknown user",
    userEmail: user?.email ?? null,
  };
}

export const listAllUsers = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  returns: v.object({
    users: v.array(
      v.object({
        _id: v.id("users"),
        email: v.string(),
        name: v.string(),
        photo: v.optional(v.id("_storage")),
        photoUrl: v.union(v.string(), v.null()),
        location: v.object({
          city: v.string(),
          province: v.string(),
          coordinates: v.optional(
            v.object({
              lat: v.number(),
              lng: v.number(),
            })
          ),
        }),
        roles: v.object({
          isSeeker: v.boolean(),
          isTasker: v.boolean(),
        }),
        createdAt: v.number(),
        updatedAt: v.number(),
      })
    ),
    cursor: v.union(v.string(), v.null()),
  }),
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
  returns: v.boolean(),
  handler: async (ctx) => {
    return await requireAdmin(ctx);
  },
});

export const getReviewAccess = query({
  args: {},
  returns: v.union(reviewAccessStatusValidator, v.null()),
  handler: async (ctx) => {
    if (!(await requireAdmin(ctx))) return null;
    return await getReviewAccessStatus(ctx);
  },
});

export const setReviewAccess = mutation({
  args: {
    enabled: v.boolean(),
  },
  returns: reviewAccessStatusValidator,
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

export const resetDatabaseCore = internalMutation({
  args: {},
  handler: async (ctx) => {
    return await performDatabaseReset(ctx);
  },
});

export const resetDatabase = mutation({
  args: {},
  handler: async (ctx) => {
    await requireAdminOrThrow(ctx);
    const { deletedUserAppUserIds: _deletedUserAppUserIds, ...result } = await performDatabaseReset(ctx);
    return result;
  },
});

export const resetDatabaseAndRevenueCat = action({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity || !ADMIN_EMAILS.has((identity.email || "").toLowerCase())) {
      throw new ConvexError("Unauthorized");
    }

    const { deletedUserAppUserIds, ...result } = await ctx.runMutation(internal.admin.resetDatabaseCore, {});
    const revenueCatCleanup = await clearRevenueCatCustomers(deletedUserAppUserIds);

    return {
      ...result,
      revenueCatCleanup,
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
      .unique();

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .unique();

    let taskerProfileWithCategories = null;
    if (taskerProfile) {
      const taskerCategories = await ctx.db
        .query("taskerCategories")
        .withIndex("by_taskerProfile_category", (q) => q.eq("taskerProfileId", taskerProfile._id))
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

    const feedbackSubmissions = await ctx.db
      .query("feedbackSubmissions")
      .withIndex("by_userId_createdAt", (q) => q.eq("userId", args.userId))
      .order("desc")
      .take(20);

    const feedbackSubmissionsEnriched = await Promise.all(
      feedbackSubmissions.map(async (submission) => await enrichFeedbackSubmission(ctx, submission))
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
      feedbackSubmissions: feedbackSubmissionsEnriched,
    };
  },
});

export const listRecentFeedback = query({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.array(feedbackSubmissionAdminValidator),
  handler: async (ctx, args) => {
    if (!(await requireAdmin(ctx))) return [];

    const limit = Math.max(1, Math.min(args.limit ?? 12, 50));
    const submissions = await ctx.db
      .query("feedbackSubmissions")
      .withIndex("by_createdAt")
      .order("desc")
      .take(limit);

    return await Promise.all(submissions.map(async (submission) => await enrichFeedbackSubmission(ctx, submission)));
  },
});
